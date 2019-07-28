#lang racket

(require "dot.rkt")
(require pict)

(provide make-digraph
         make-subgraph
         make-vertex
         make-edge
         (struct-out digraph)
         (struct-out vertex)
         (struct-out edge)
         (struct-out subgraph)
         digraph->dot
         digraph->pict
         digraph-node-picts)

(struct digraph (objects))
(struct vertex (name label shape))
(struct edge (nodes))
(struct subgraph (label objects))

(define (make-digraph defs)
  (digraph (map make-object defs)))

(define (make-subgraph name defs)
  (subgraph name (map make-object defs)))

(define (make-object def)
  (cond [(and (string? def) (string-contains? def "->")) (make-edge def)]
        [(subgraph? def) def]
        [else (make-vertex def)]))

(define (make-vertex s)
  (cond [(string? s) (vertex s s "record")]
        [(list? s) (list->vertex s)]
        [(vertex? s) s]))

(define (make-edge s)
  (edge (string-split s #rx"[ ]*->[ ]*")))

(define (digraph-node-picts d)
  (make-hash
   (for/list ([v (digraph-vertices d)]
              #:when (pict? (vertex-shape v)))
     (cons (vertex-name v) (vertex-shape v)))))


(define (digraph-vertices d)
  (find-vertices (digraph-objects d)))

(define (subgraph-vertices d)
  (find-vertices (subgraph-objects d)))

(define (find-vertices objs)
  (define outer-vertices (filter vertex? objs))
  (define subgraphs (filter subgraph? objs))
  (define nested-vertices (map subgraph-vertices subgraphs))
  (append outer-vertices (apply append nested-vertices)))

(define (digraph->pict d)
  (dot->pict (digraph->dot d)
             #:node-picts (digraph-node-picts d)))

(define (list->vertex lst)
  (define (aux lst name label shape)
    (cond [(empty? lst)              (vertex name label shape)]
          [(eq? (first lst) `#:shape)  (aux (cddr lst) name label (second lst))]
          [(eq? (first lst) `#:label)  (aux (cddr lst) name (second lst) shape)]))
  (aux (cdr lst) (first lst) (first lst) "record"))

(define (digraph->dot d)
  (define defs (objects->dot (digraph-objects d)))
  (string-append "digraph {\n"
                 (indent 4 defs)
                 "\n}"))

(define (indent n s)
  (define lines (string-split s "\n"))
  (define line-prefix (repeat n " "))
  (define indented-lines
    (map (curry string-append line-prefix) lines))
  (string-join indented-lines "\n"))

(define (repeat n s)
  (apply string-append
         (for/list ([x (in-range n)])
           s)))

(define (objects->dot objs)
  (string-join (map object->dot objs) "\n"))

(define (object->dot obj)
  (cond [(vertex? obj) (vertex->dot obj)]
        [(edge? obj) (edge->dot obj)]
        [(subgraph? obj) (subgraph->dot obj)]
        [else ""]))


(define (subgraph->dot d)
  (define defs (objects->dot (subgraph-objects d)))
  (string-append "subgraph "
                 "cluster_" (number->string (random 1 32000000))
                 " {\n"
                 "label=" (quote-string (subgraph-label d)) "\n"
                 (indent 4 defs)
                 "\n}"))

(define (vertex->dot v)
  (match v
    [(vertex name label shape)
     (define shape-str (if (pict? shape)
                           "record"
                           shape))
     (define basic-properties `(("label" ,label)
                          ("shape" ,shape-str)))
     (define size-properties
       (cond
         [(pict? shape) `(("fixedsize" "true")
                          ("height" ,(number->string (/ (pict-height shape) 72.)))
                          ("width" ,(number->string (/ (pict-width shape) 72.))))]
         [else `()]))

     (define properties (append basic-properties size-properties))
     (string-append name (properties->string properties))]))

(define (edge->dot e)
  (string-join (edge-nodes e) " -> "))

(define (properties->string ps)
  (string-join (map property->string ps) " "
               #:before-first "["
               #:after-last   "]"))

(define (property->string p)
  (string-append (first p) "=" (quote-string (second p))))

(define (quote-string s)
  (string-append "\"" (string-replace s "\"" "\\\"") "\""))
