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
         (define state (make-hasheq))
         (for ([instruction (in-list (hash-ref object key '()))])
           (with-handlers ([exn:fail?
                            (lambda (error)
                              (raise-arguments-error
                               'dot->pict (exn-message error)
                               "object" name "drawing" key
                               "instruction" instruction))])
             (apply-instruction dc instruction state)))))
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

(define installed-faces (delay (get-face-list)))

(define (graphviz-font size face)
  (define family
    (cond [(regexp-match? #rx"(?i:courier|mono)" face) 'modern]
          [(regexp-match? #rx"(?i:arial|helvetica|sans)" face) 'swiss]
          [else 'roman]))
  (define aliases
    (case family
      [(modern) '("Courier New" "Nimbus Mono PS" "Liberation Mono" "DejaVu Sans Mono")]
      [(swiss) '("Arial" "Arimo" "Helvetica" "Nimbus Sans" "Liberation Sans")]
      [else '("Times New Roman" "Nimbus Roman" "Liberation Serif" "DejaVu Serif")]))
  (define selected
    (for*/first ([candidate (in-list (cons face aliases))]
                 [installed (in-list (force installed-faces))]
                 #:when (string-ci=? candidate installed))
      installed))
  (make-font #:size size #:face selected #:family family
             #:weight (if (regexp-match? #rx"(?i:bold)" face) 'bold 'normal)
             #:style (if (regexp-match? #rx"(?i:italic|oblique)" face) 'italic 'normal)
             #:size-in-pixels? #t #:hinting 'unaligned))

(define (apply-instruction dc instruction state)
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
    [(hash-table ('op "F") ('size size) ('face face))
     (define font (graphviz-font size face))
     (send dc set-font font)
     (when (hash? state)
       (hash-set! state 'font font)
       (hash-set! state 'flags 0))]
    [(hash-table ('op "t") ('fontchar flags))
     (unless (and (exact-integer? flags) (<= 0 flags 127))
       (error 'dot->pict "invalid font characteristics: ~a" flags))
     (define font (if (hash? state) (hash-ref state 'font (send dc get-font))
                      (send dc get-font)))
     (define (flag? bit) (bitwise-bit-set? flags bit))
     (send dc set-font
           (make-font #:size (* (send font get-size)
                               (if (or (flag? 3) (flag? 4)) 0.8 1))
                      #:face (send font get-face)
                      #:family (send font get-family)
                      #:style (if (flag? 1) 'italic (send font get-style))
                      #:weight (if (flag? 0) 'bold (send font get-weight))
                      #:underlined? (flag? 2)
                      #:size-in-pixels? (send font get-size-in-pixels)
                      #:hinting 'unaligned))
     (when (hash? state) (hash-set! state 'flags flags))]
    [(hash-table ('op "T") ('pt (list x y)) ('align align)
                 ('width width) ('text text))
     (define-values (w h descent space) (send dc get-text-extent text))
     (define flags (if (hash? state) (hash-ref state 'flags 0) 0))
     (define font (if (hash? state) (hash-ref state 'font (send dc get-font))
                      (send dc get-font)))
     (define baseline
       (+ y (* (send font get-size)
               (cond [(bitwise-bit-set? flags 3) -0.35]
                     [(bitwise-bit-set? flags 4) 0.2]
                     [else 0]))))
     (define left
       (match align
         ["l" x] ["c" (- x (/ w 2))] ["r" (- x w)]
         [_ (error 'dot->pict "invalid text alignment: ~a" align)]))
     (send dc draw-text text left (- baseline (- h descent)))
     (when (or (bitwise-bit-set? flags 5) (bitwise-bit-set? flags 6))
       (call-with-dc-state
        dc
        (lambda ()
          (send dc set-pen (send dc get-text-foreground) 1 'solid)
          (for ([bit '(5 6)] [fraction '(0.35 0.9)])
            (when (bitwise-bit-set? flags bit)
              (define line-y (- baseline (* fraction (- h descent))))
              (send dc draw-line left line-y (+ left w) line-y))))))]
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
