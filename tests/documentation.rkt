#lang racket
(require rackunit pict racket/draw "../scribblings/utils.rkt")
(define (pixels bitmap)
  (define data (make-bytes (* 4 (send bitmap get-width) (send bitmap get-height))))
  (send bitmap get-argb-pixels 0 0 (send bitmap get-width) (send bitmap get-height) data)
  data)
(module+ test
  (when (find-executable-path "dot")
    (define input "digraph {a [label=\"\",width=1,height=1]}")
    (define (render color)
      (dot->pict-cached input #:node-picts
                        (hash "a" (colorize (filled-rectangle 20 20) color))))
    (check-not-equal? (pixels (render "red")) (pixels (render "blue")))
    (check-not-equal?
     (pixels (dot->pict-cached "digraph {a [label=\"a b\"]}"))
     (pixels (dot->pict-cached "digraph {a [label=\"ab\"]}")))
    (define directory (make-temporary-file "graphviz-docs~a" 'directory))
    (dynamic-wind
      void
      (lambda ()
        (parameterize ([current-directory directory])
          (check-true (is-a? (render "green") bitmap%))
          (check-equal? (directory-list) '())))
      (lambda () (delete-directory/files directory)))))
