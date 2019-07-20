#lang racket

(require pict)
(require json)
(require racket/draw)

(provide run-dot dot->pict)

;;
;; converts the given dot definition to a pict
;;
(define (dot->pict str)
  (define dot-output (run-dot str "json"))
  (define xdot-json (read-json dot-output))
  (xdot-json->pict xdot-json))

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
     (ctl 'wait)
     stdout]))

;;
;; converts output of dot in json format to a pict
;;
(define (xdot-json->pict jsexpr)
  (define bounding-box
    (string->numlist (hash-ref jsexpr 'bb) ","))
  (define scale 1.25)
  (define width (* scale (third bounding-box)))
  (define height (* scale (second bounding-box)))
  (define draw
    (λ (dc dx dy)
      ;; save dc state
      (define smoothing (send dc get-smoothing))
      (define transformation (send dc get-transformation))

      ;; defaults
      (send dc set-smoothing `smoothed)
      (send dc set-initial-matrix (vector scale 0.0 0.0 scale dx dy))

      ;; actual drawing
      (xdot-object-draw dc jsexpr)

      ;; restore dc state
      (send dc set-transformation transformation)
      (send dc set-smoothing smoothing)
      ))
  (dc draw width height))


;;
;; drwas a given "dot" object (in json format) on the given dc
;;
(define (xdot-object-draw dc jsexpr)
  ;; save state
  (define brush (send dc get-brush))
  (define pen (send dc get-pen))
  (define font (send dc get-font))
  (define text-foreground (send dc get-text-foreground))
  
  ;; apply drawing instructions
  (for* ([draw-label `(_draw_ _ldraw_ _hdraw_ _tdraw_)]
         [instruction (hash-ref jsexpr draw-label `())])
    (apply-instruction dc instruction))
  ;; recursively draw objects
  (for* ([object (hash-ref jsexpr `objects `())])
    (xdot-object-draw dc object))
  ;; recursively draw edges
  (for* ([edge (hash-ref jsexpr `edges `())])
    (if (hash? edge)
        (xdot-object-draw dc edge)
        `()))

  ;; restore state
  (send dc set-pen pen)
  (send dc set-brush brush)
  (send dc set-font font)
  (send dc set-text-foreground text-foreground))


;;
;; Applies the given "dot" instruction
;;
(define (apply-instruction dc instruction)
  (match instruction

    ;; set color
    [(hash-table (`op "c") (`color colorstr) (`grad grad))
     (define color (string->color colorstr))
     (send dc set-pen color 1.25 `solid)
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
     (define left
       (match align
         ["l" x]
         ["c" (- x (/ w 2))]
         ["r" (- x w)]
         [else x]))
     (send dc draw-text text left (- y (/ h 2) d))]
    
    ;; draw spline
    [(hash-table (`op "b") (`points points))
     (define (draw-spline pts)
       (cond
         [(>= (length pts) 3)
          (define p1 (first pts))
          (define p2 (second pts))
          (define p3 (third pts))
          (send dc draw-spline
                (first p1) (second p1)
                (first p2) (second p2)
                (first p3) (second p3))
          (draw-spline (cddr pts))]
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
     0]
    ))


;;
;; Misc. utility functions
;;


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