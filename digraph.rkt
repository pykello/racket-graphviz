#lang racket

(require "dot.rkt")
(require pict)

(provide (struct-out digraph)
         (struct-out vertex)
         (struct-out edge)
         make-digraph
         make-vertex
         make-edge
         digraph->dot)

(struct digraph (vertices edges))
(struct vertex (name label shape))
(struct edge (nodes))

(define (make-digraph vertices edges)
  (digraph (map make-vertex vertices)
           (map make-edge edges)))

(define (make-vertex s)
  (cond [(string? s) (vertex s s "record")]
        [(list? s) (list->vertex s)]
        [(vertex? s) s]))

(define (make-edge s)
  (string-split s #rx"[ ]*->[ ]*"))

(define (list->vertex lst)
  (define (aux lst name label shape)
    (cond [(empty? lst)              (vertex name label shape)]
          [(eq? (first lst) `#:shape)  (aux (cddr lst) name label (second lst))]
          [(eq? (first lst) `#:label)  (aux (cddr lst) name (second lst) shape)]))
  (aux (cdr lst) (first lst) (first lst) "record"))

(define (digraph->dot d)
  (define vertex-defs
    (string-append (vertices->dot (digraph-vertices d))
                   "\n"
                   (edges->dot (digraph-edges d))))
  (string-append "digraph {\n"
                 (indent 4 vertex-defs)
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

(define (vertices->dot vs)
  (string-join (map vertex->dot vs) "\n"))

(define (edges->dot es)
  (string-join (map edge->dot es) "\n"))

(define (vertex->dot v)
  (match v
    [(vertex name label shape)
     (define shape-str (if (pict? shape)
                           "record"
                           shape))
     (define properties `(("label" ,label)
                          ("shape" ,shape-str)))
     (string-append name (properties->string properties))]))

(define (edge->dot e)
  (string-join e " -> "))

(define (properties->string ps)
  (string-join (map property->string ps) " "
               #:before-first "["
               #:after-last   "]"))

(define (property->string p)
  (string-append (first p)
                 "=\""
                 (string-replace (second p) "\"" "\\\"")
                 "\""))
