#lang racket
(require rackunit pict racket/draw json racket/runtime-path
         "../lib/private/render.rkt")
(define-runtime-path fixtures "fixtures")
(define (pixel bitmap x y)
  (define bytes (make-bytes 4))
  (send bitmap get-argb-pixels x y 1 1 bytes)
  bytes)
(module+ test
  (define bitmap (make-bitmap 50 50))
  (define dc (new bitmap-dc% [bitmap bitmap]))
  (send dc set-background "blue")
  (send dc clear)
  (send dc set-brush "red" 'solid)
  (for ([op '("e" "p")])
    (apply-instruction dc
                      (if (equal? op "e")
                          (hash 'op op 'rect '(25 25 10 10))
                          (hash 'op op 'points '((10 10) (40 10) (25 40)))) '())
    (check-equal? (pixel bitmap 25 25) #"\377\0\0\377")
    (check-equal? (send (send dc get-brush) get-style) 'solid))
  (check-equal? (send (string->color "#ff000000") alpha) 0.0)
  (check-equal? (send (string->color "#ff0000") alpha) 1.0)
  (define before (send dc get-transformation))
  (check-exn exn:fail?
             (lambda ()
               (call-with-dc-state dc (lambda () (send dc translate 9 12)
                                        (error 'test "failure")))))
  (check-equal? before (send dc get-transformation))
  (check-exn #rx"unsupported Graphviz"
             (lambda () (apply-instruction dc (hash 'op "I") '())))
  (define empty (xdot-json->pict (hash 'bb "10,40,30,20") (hash)))
  (check-equal? (pict-width empty) 22)
  (check-equal? (pict-height empty) 22)
  (define custom (colorize (filled-rectangle 10 10) "red"))
  (define graph
    (hash 'bb "10,40,50,20"
          'objects (list (hash 'name "node" 'pos "30,30"))))
  (define custom-image (xdot-json->pict graph (hash "node" custom)))
  (check-equal? (pixel (pict->bitmap custom-image) 21 11) #"\377\377\0\0")
  (check-equal? (pixel (pict->bitmap (inset (scale custom-image 2) 5)) 47 27)
                #"\377\377\0\0")
  (check-true (send (pict->bitmap (rotate custom-image 0.5)) ok?))
  (define labels
    (for/list ([key '(_ldraw_ _hldraw_ _tldraw_)] [x '(10 30 50)])
      (cons key (list (hash 'op "C" 'color "#ff0000" 'grad "none")
                      (hash 'op "E" 'rect (list x 10 3 3))))))
  (define label-image
    (pict->bitmap (xdot-json->pict (hash-set (make-immutable-hash labels) 'bb "0,20,60,0")
                                  (hash))))
  (for ([x '(11 31 51)])
    (check-equal? (pixel label-image x 11) #"\377\377\0\0"))
  (apply-instruction dc
                     (hash 'op "b" 'points '((1 1) (2 3) (4 5) (6 7)
                                            (8 9) (10 11) (12 13))) '())
  (check-exn #rx"invalid cubic spline"
             (lambda () (apply-instruction dc (hash 'op "b" 'points '((1 1) (2 2))) '())))
  (for ([name '("shapes" "labels" "large")])
    (define graph (call-with-input-file (build-path fixtures (string-append name ".json")) read-json))
    (define image (xdot-json->pict graph (hash)))
    (check-true (positive? (pict-width image)))
    (check-true (send (pict->bitmap (scale image 0.5)) ok?))))
