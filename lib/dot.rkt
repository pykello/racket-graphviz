#lang racket

(require pict
         json
         racket/draw
         (only-in metapict
                  bez
                  pt
                  bez->dc-path))

(provide (contract-out
          [run-dot (-> string? string? port?)]
          [dot->pict (->* (string?) (#:node-picts hash?) pict?)]))

;;
;; converts the given dot definition to a pict
;;
(define (dot->pict str #:node-picts [node-picts (make-immutable-hash)])
  (define dot-output (run-dot str "json"))
  (define xdot-json (read-json dot-output))
  (xdot-json->pict xdot-json node-picts))

;;
;; runs "dot" and returns the stdout port
;;
(define (run-dot str format)
  (define cmd (string-append "dot -y -T" format))
  (match (process cmd)
    [(list stdout stdin pid stderr ctl)
     (write-string str stdin)
     (newline stdin)
     (close-output-port stdin)
     (define output (read-process-output stdout ctl))
     (cond [(eq? (ctl 'status) 'done-error) (error (port->string stderr))]
           [else (open-input-string output)])]))


;;
;; Reads the process output until eof, or timeout, or error
;;
(define (read-process-output port ctl [timeout 5000])
  (define expire (+ (current-inexact-milliseconds) timeout))
  (define (test-func)
    (or (equal? (ctl 'status) 'done-error)
        (> (current-inexact-milliseconds) expire)))
  (read-until port test-func))


(define (read-until port test-func)
  (define (read-until-rec)
    (cond
      [(test-func) '()]
      [else (define bs (make-bytes 4096))
            (define result (read-bytes-avail!* bs port))
            (if (eof-object? result)
                '()
                (cons (bytes->string/utf-8 (subbytes bs 0 result))
                      (read-until-rec)))]))
  (apply string-append (read-until-rec)))

;;
;; converts output of dot in json format to a pict
;;
(define (xdot-json->pict jsexpr node-picts)
  (define bounding-box
    (string->numlist (hash-ref jsexpr 'bb) ","))
  (define scale 1)
  (define width (+ 2 (* scale (third bounding-box))))
  (define height (+ 2 (* scale (second bounding-box))))
  (define draw
    (λ (dc dx dy)
      ;; save dc state
      (define smoothing (send dc get-smoothing))
      (define transformation (send dc get-transformation))
      (define pen (send dc get-pen))

      (define-values
        (xx xy yx yy x0 y0)
        (vector->values (send dc get-initial-matrix)))

      ;; defaults
      (send dc set-smoothing `smoothed)
      (send dc set-initial-matrix (vector xx xy yx yy
                                          (+ 1 x0 (* dx xx) (* dy xy))
                                          (+ 1 y0 (* dx yx) (* dy yy))))
      (send dc set-pen (new pen%
                            [color "black"]
                            [style `solid]
                            [width 1.25]
                            [cap `butt]
                            [join `round]
                            [stipple #f]))

      ;; actual drawing
      (xdot-object-draw dc jsexpr node-picts (make-hash))

      ;; restore dc state
      (send dc set-transformation transformation)
      (send dc set-smoothing smoothing)
      (send dc set-pen pen)
      ))
  (dc draw width height))


;;
;; drwas a given "dot" object (in json format) on the given dc
;;
(define (xdot-object-draw dc jsexpr node-picts extra)
  ;; save state
  (define brush (send dc get-brush))
  (define pen (send dc get-pen))
  (define font (send dc get-font))
  (define text-foreground (send dc get-text-foreground))

  (define name (hash-ref jsexpr `name "XYZ"))
  (define node-pict (hash-ref node-picts name #f))
  (define spline-instruction
    (filter (λ (x) (equal? (hash-ref x `op) "b"))
            (hash-ref jsexpr `_draw_ `())))
  (define spline-pts
    (cond
      [(or (null? spline-instruction)
           (not (hash-has-key? jsexpr `head))) `()]
      [else (hash-ref (car spline-instruction) `points `())]))

  (cond
    [(pict? node-pict)
     (let* ([pos (hash-ref jsexpr `pos "0,0")]
            [pos-list (string->numlist pos ",")]
            [pos-x (- (first pos-list) (/ (pict-width node-pict) 2))]
            [pos-y (- (second pos-list) (/ (pict-height node-pict) 2))])
       (draw-pict node-pict dc pos-x pos-y))]
    [else #f])

  ;; if a shape is associated with node, just draw the label
  (define draw-keys
    (cond [(pict? node-pict) `(_ldraw_)]
          [else `(_draw_ _ldraw_ _hdraw_ _tdraw_)]))

  ;; apply drawing instructions
  (for* ([key draw-keys]
         [instruction (hash-ref jsexpr key `())])
    (apply-instruction dc instruction spline-pts))

  ;; recursively draw objects
  (for* ([object (hash-ref jsexpr `objects `())])
    (xdot-object-draw dc object node-picts extra))
  ;; recursively draw edges
  (for* ([edge (hash-ref jsexpr `edges `())])
    (if (hash? edge)
        (xdot-object-draw dc edge node-picts extra)
        `()))

  ;; restore state
  (send dc set-pen pen)
  (send dc set-brush brush)
  (send dc set-font font)
  (send dc set-text-foreground text-foreground))


;;
;; Applies the given "dot" instruction
;;
(define (apply-instruction dc instruction edge-spline)
  (match instruction

    ;; set color
    [(hash-table (`op "c") (`color color) (`grad grad))
     (define old-pen
       (send dc get-pen))
     (define new-pen
       (update-pen old-pen `color (string->color color)))
     (send dc set-pen new-pen)
     (send dc set-text-foreground color)]

    ;; set fill
    [(hash-table (`op "C") (`color color) (`grad grad))
     (send dc set-brush (string->color color) `solid)]

    ;; draw filled polygon
    [(hash-table (`op "P") (`points points))
     (send dc draw-polygon (make-points points))]

    ;; draw unfilled polygon
    [(hash-table (`op "p") (`points points))
     (send dc draw-polygon (make-points points))]

    ;; draw unfilled ellipse
    [(hash-table (`op "e") (`rect (list x y w h)))
     (send dc draw-ellipse (- x w) (- y h) (* 2 w) (* 2 h))]

    ;; draw filled ellipse
    [(hash-table (`op "E") (`rect (list x y w h)))
     (send dc draw-ellipse (- x w) (- y h) (* 2 w) (* 2 h))]

    ;; polyline
    [(hash-table (`op "L") (`points points))
     (define points-paired
       (for/list ([p points]) (cons (first p) (second p))))
     (send dc draw-lines points-paired)]

    ;; set font
    [(hash-table (`op "F") (`size size) (`face face))
     (define family
       (match face
         ["Arial" `swiss]
         [else `roman]))
     (define size-scaler
       (match face
         ["Arial" 0.8]
         [else 0.75]))
     (send dc set-font (make-object font% (* size size-scaler) family))]

    ;; set font characteristics
    [(hash-table (`op "t") (`fontchar f))
     (define font (send dc get-font))
     (define style
       (if (= f 2)
           `italic
           (send font get-style)))
     (define weight
       (if (= f 1)
           `bold
           (send font get-weight)))
     (define underlined
       (if (= f 4)
           `#t
           (send font get-underlined)))
     (define new-font
       (make-object font%
         (send font get-size)
         (send font get-family)
         style
         weight
         underlined))
     (send dc set-font new-font)]

    ;; draw text
    [(hash-table (`op "T") (`pt (list x y)) (`align align) (`width width) (`text text))
     (define-values (w h d c) (send dc get-text-extent text))
     (define preferred-x
       (calculate-text-left x y edge-spline))
     (define left
       (cond
         [(number? preferred-x) (- preferred-x (/ width 2) 10)]
         [(equal? align "l") x]
         [(equal? align "c") (- x (/ w 2))]
         [(equal? align "r") (- x w)]
         [else x]))
     (cond
       [(number? preferred-x) (let ([pen (send dc get-pen)])
                                (send dc set-pen "white" 0 `solid)
                                (send dc draw-rectangle left (- y (* h 0.75)) w h)
                                (send dc set-pen pen))]
       [else 0])
     (send dc draw-text text left (- y (/ h 2) d))]
    
    ;; draw spline
    [(hash-table (`op "b") (`points points))
     (define (draw-spline pts)
       (cond
         [(= (length pts) 3)
          (define p1 (first pts))
          (define p2 (second pts))
          (define p3 (third pts))
          (send dc draw-spline
                (first p1) (second p1)
                (first p2) (second p2)
                (first p3) (second p3))]
         [(>= (length pts) 4)
          (define (pair->pt p)
            (pt (first p) (second p)))
          (define path (bez->dc-path
                        (bez (pair->pt (first pts))
                             (pair->pt (second pts))
                             (pair->pt (third pts))
                             (pair->pt (fourth pts)))))
          (send dc draw-path path)
          (draw-spline (cdddr pts))]
         [(= (length pts) 2)
          (define p1 (first pts))
          (define p2 (second pts))
          (send dc draw-line
                (first p1) (second p1)
                (first p2) (second p2))]
         [else 0])
       )
     (draw-spline points)]

    ;; set style
    [(hash-table (`op "S") (`style style))
     (define cmd (string-split style #rx"\\(|\\)"))
     (define old-pen (send dc get-pen))
     (define new-pen
       (match cmd
         [(list "setlinewidth" width)
          (update-pen old-pen `width (string->number width))]
         [(list "solid")
          (update-pen old-pen `style `solid)]
         [(list "dashed")
          (update-pen old-pen `style `long-dash)]
         [(list "dotted")
          (update-pen old-pen `style `dot)]
         [(list "invis")
          (update-pen old-pen `style `transparent)]
         [else old-pen]))
     (send dc set-pen new-pen)]
    ))


;;
;; Misc. utility functions
;;


(define (calculate-text-left x y edge-spline)
  (cond
    [(< (length edge-spline) 2) `()]
    [else (define p1 (first edge-spline))
          (define p2 (second edge-spline))
          (if (and (between y (second p1) (second p2))
                   #t)
              (first p1)
              (calculate-text-left x y (cdr edge-spline)))]))

(define (between a b c)
  (or (< b a c)
      (< c a b)))

(define (make-points lst)
  (for/list ([p lst])
    (make-object point% (first p) (second p))))

(define (string->color s)
  (define r (substring s 1 3))
  (define g (substring s 3 5))
  (define b (substring s 5 7))
  (make-object color%
    (string->number r 16)
    (string->number g 16)
    (string->number b 16)))

(define (string->numlist s sep)
  (map string->number (string-split s sep)))

(define (update-pen pen attr value)
  (define color
    (if (eq? attr `color)
        value
        (send pen get-color)))
  (define width
    (if (eq? attr `width)
        value
        (send pen get-width)))
  (define style
    (if (eq? attr `style)
        value
        (send pen get-style)))
  (new pen%
       [color color]
       [width width]
       [style style]
       [cap (send pen get-cap)]
       [join (send pen get-join)]
       [stipple (send pen get-stipple)]))
