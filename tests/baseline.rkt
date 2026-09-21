#lang racket
(require rackunit pict json "../lib/digraph.rkt" "../lib/dot.rkt")

(module+ test
  (define fish (standard-fish 60 30))
  (define a (make-vertex "a" #:shape fish))
  (define b (make-vertex "b"))
  (define graph (make-digraph (list a b (make-edge a b)) #:rankdir "LR"))
  (check-eq? (hash-ref (digraph-node-picts graph) (vertex-name a)) fish)
  (check-equal? (edge-nodes (make-edge a b))
                (list (vertex-name a) (vertex-name b)))
  (check-true (string-contains? (digraph->dot graph) "rankdir=\"LR\""))
  (when (find-executable-path "dot")
    (define result (digraph->pict graph))
    (check-true (pict? result))
    (check-true (positive? (pict-width result)))
    (check-true (positive? (pict-height result)))))
