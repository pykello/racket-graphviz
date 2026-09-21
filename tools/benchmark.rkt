#lang racket
(require json "../main.rkt" "../lib/private/render.rkt")

(define (measure thunk)
  (collect-garbage)
  (define allocated (current-memory-use 'cumulative))
  (define peak (box (current-memory-use)))
  (define sampler
    (thread (lambda ()
              (let loop ()
                (set-box! peak (max (unbox peak) (current-memory-use)))
                (sleep 0.01)
                (loop)))))
  (define start (current-inexact-monotonic-milliseconds))
  (define result (dynamic-wind void thunk (lambda () (kill-thread sampler))))
  (values result
          (hash 'milliseconds (- (current-inexact-monotonic-milliseconds) start)
                'allocated-bytes (- (current-memory-use 'cumulative) allocated)
                'sampled-memory-bytes (max (unbox peak) (current-memory-use)))))

(module+ main
  (define counts '(10 100 500))
  (define results
    (for/list ([count (in-list counts)])
      (define-values (graph construct)
        (measure (lambda ()
                   (make-digraph
                    (for/list ([i (in-range (sub1 count))])
                      (list 'edge (list (format "n~a" i) (format "n~a" (add1 i)))))
                    #:rankdir "LR"))))
      (define-values (dot serialize) (measure (lambda () (digraph->dot graph))))
      (define-values (bytes process)
        (measure (lambda ()
                   (define input (run-dot dot "json"))
                   (dynamic-wind void (lambda () (port->bytes input))
                                 (lambda () (close-input-port input))))))
      (define-values (json parse) (measure (lambda () (read-json (open-input-bytes bytes)))))
      (define-values (picture render) (measure (lambda () (xdot-json->pict json (hash)))))
      (define-values (bitmap draw)
        (measure (lambda () (pict->bitmap (scale picture (min 1 (/ 2000 (pict-width picture))))))))
      (hash 'nodes count 'construct construct 'serialize serialize 'process process
            'parse parse 'render render 'draw draw)))
  (write-json (hash 'racket (version) 'platform (symbol->string (system-type))
                    'memory-note "Sampled Racket memory; excludes Graphviz child memory"
                    'results results))
  (newline))
