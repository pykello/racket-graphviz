#lang racket

(require pict racket/draw)

(provide xdot-json->pict apply-instruction string->color call-with-dc-state)

(define (call-with-dc-state dc thunk)
  (define pen (send dc get-pen))
  (define brush (send dc get-brush))
  (define font (send dc get-font))
  (define foreground (send dc get-text-foreground))
  (define smoothing (send dc get-smoothing))
  (define transformation (send dc get-transformation))
  (dynamic-wind
    void thunk
    (lambda ()
      (send dc set-pen pen)
      (send dc set-brush brush)
      (send dc set-font font)
      (send dc set-text-foreground foreground)
      (send dc set-smoothing smoothing)
      (send dc set-transformation transformation))))

(define (numbers value count)
  (define result (map string->number (string-split value ",")))
  (unless (and (= (length result) count) (andmap rational? result))
    (raise-arguments-error 'dot->pict "invalid Graphviz coordinates" "value" value))
  result)

(define (xdot-json->pict graph node-picts)
  (match-define (list x0 y0 x1 y1) (numbers (hash-ref graph 'bb "0,0,0,0") 4))
  (define left (min x0 x1))
  (define top (min y0 y1))
  (define (draw dc dx dy)
    (call-with-dc-state
     dc
     (lambda ()
       (send dc translate (+ dx 1 (- left)) (+ dy 1 (- top)))
       (send dc set-smoothing 'smoothed)
       (send dc set-pen (new pen% [color "black"] [width 1]
                            [cap 'butt] [join 'round]))
       (send dc set-brush "white" 'transparent)
       (draw-object dc graph node-picts))))
  (dc draw (+ 2 (abs (- x1 x0))) (+ 2 (abs (- y1 y0)))))

(define (draw-object dc object node-picts)
  (call-with-dc-state
   dc
   (lambda ()
     (define name (hash-ref object 'name #f))
     (define custom (hash-ref node-picts name #f))
     (define (instructions keys)
       (for ([key (in-list keys)])
         (for ([instruction (in-list (hash-ref object key '()))])
           (with-handlers ([exn:fail?
                            (lambda (error)
                              (raise-arguments-error
                               'dot->pict (exn-message error)
                               "object" name "drawing" key
                               "instruction" instruction))])
             (apply-instruction dc instruction '())))))
     (when (pict? custom)
       (match-define (list x y) (numbers (hash-ref object 'pos) 2))
       (draw-pict custom dc (- x (/ (pict-width custom) 2))
                  (- y (/ (pict-height custom) 2))))
     (unless (pict? custom) (instructions '(_draw_ _tdraw_ _hdraw_)))
     (define objects (filter hash? (hash-ref object 'objects '())))
     (define edges (filter hash? (hash-ref object 'edges '())))
     (define-values (nodes clusters)
       (partition (lambda (o) (hash-has-key? o 'pos)) objects))
     (for ([cluster (in-list clusters)]) (draw-object dc cluster node-picts))
     (define ordered
       (if (equal? (hash-ref object 'outputorder "") "nodesfirst")
           (append nodes edges) (append edges nodes)))
     (for ([child (in-list ordered)]) (draw-object dc child node-picts))
     (instructions '(_ldraw_ _hldraw_ _tldraw_)))))

(define (unfilled dc draw)
  (define brush (send dc get-brush))
  (dynamic-wind
    (lambda () (send dc set-brush "white" 'transparent))
    draw
    (lambda () (send dc set-brush brush))))

(define (points->path points)
  (unless (and (>= (length points) 4) (= (modulo (sub1 (length points)) 3) 0))
    (raise-arguments-error 'dot->pict "invalid cubic spline" "points" points))
  (define path (new dc-path%))
  (send/apply path move-to (first points))
  (let loop ([rest (cdr points)])
    (unless (null? rest)
      (send/apply path curve-to (append (first rest) (second rest) (third rest)))
      (loop (cdddr rest))))
  path)

(define (apply-instruction dc instruction edge-spline)
  (match instruction
    [(hash-table ('op "c") ('color color) ('grad "none"))
     (define parsed (string->color color))
     (send dc set-pen (update-pen (send dc get-pen) 'color parsed))
     (send dc set-text-foreground parsed)]
    [(hash-table ('op "C") ('color color) ('grad "none"))
     (send dc set-brush (string->color color) 'solid)]
    [(hash-table ('op (and op (or "P" "p"))) ('points points))
     (define (draw) (send dc draw-polygon (map (lambda (p) (cons (first p) (second p))) points)))
     (if (equal? op "p") (unfilled dc draw) (draw))]
    [(hash-table ('op (and op (or "E" "e"))) ('rect (list x y w h)))
     (define (draw) (send dc draw-ellipse (- x w) (- y h) (* 2 w) (* 2 h)))
     (if (equal? op "e") (unfilled dc draw) (draw))]
    [(hash-table ('op "L") ('points points))
     (send dc draw-lines (map (lambda (p) (cons (first p) (second p))) points))]
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
    
    [(hash-table ('op (and op (or "b" "B"))) ('points points))
     (define (draw) (send dc draw-path (points->path points)))
     (if (equal? op "b") (unfilled dc draw) (draw))]
    [(hash-table ('op "S") ('style style))
     (define pen (send dc get-pen))
     (match (string-split style #rx"\\(|\\)")
       [(list "setlinewidth" width)
        (define value (string->number width))
        (unless (and (rational? value) (<= 0 value 255))
          (error 'dot->pict "unsupported pen width: ~a" width))
        (send dc set-pen (update-pen pen 'width value))]
       [(list (and style (or "solid" "dashed" "dotted" "invis")))
        (send dc set-pen
              (update-pen pen 'style
                          (hash-ref (hash "solid" 'solid "dashed" 'long-dash
                                          "dotted" 'dot "invis" 'transparent) style)))]
       [_ (error 'dot->pict "unsupported Graphviz style: ~a" style)])]
    [_ (raise-arguments-error 'dot->pict "unsupported Graphviz drawing operation"
                              "instruction" instruction)]))

(define (calculate-text-left x y points)
  (cond
    [(< (length points) 2) #f]
    [(or (< (second (first points)) y (second (second points)))
         (< (second (second points)) y (second (first points))))
     (first (first points))]
    [else (calculate-text-left x y (cdr points))]))

(define (string->color value)
  (unless (regexp-match? #px"^#[0-9a-fA-F]{6}(?:[0-9a-fA-F]{2})?$" value)
    (raise-arguments-error 'dot->pict "unsupported Graphviz color" "color" value))
  (define (component start) (string->number (substring value start (+ start 2)) 16))
  (make-object color% (component 1) (component 3) (component 5)
               (if (= (string-length value) 9) (/ (component 7) 255.0) 1.0)))

(define (update-pen pen attribute value)
  (new pen%
       [color (if (eq? attribute 'color) value (send pen get-color))]
       [width (if (eq? attribute 'width) value (send pen get-width))]
       [style (if (eq? attribute 'style) value (send pen get-style))]
       [cap (send pen get-cap)] [join (send pen get-join)]
       [stipple (send pen get-stipple)]))
