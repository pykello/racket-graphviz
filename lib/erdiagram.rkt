#lang racket

(require pict
         "dot.rkt"
         "digraph.rkt")

(provide er-diagram)

(define (er-diagram tables relations)
  (define vertices
    (map table->vertex tables))
  (define edges
    (map relation->edge relations))
  (define digraph
    (make-digraph
     (append vertices edges)
     #:ortho "true"))
  (digraph->pict digraph))

(define (table->vertex table)
  (define title (first table))
  (define attrs (second table))
  (define label
    (string-append "{" title "|"
                   (string-join attrs "\\n")
                   "}"))
  `(,title #:label ,label
           #:shape "record"
           #:width "2"))

(define (relation->edge relation)
  (match relation
    [(list head tail t-arity h-arity)
     (list (list head tail)
           '#:dir "both"
           '#:arrowhead (arity-shape h-arity)
           '#:arrowtail (arity-shape t-arity))]))

(define (arity-shape arity)
  (match arity
    [(quasiquote 'many) "crow"]
    [(quasiquote 'one) "none"]))
