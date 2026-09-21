#lang racket

(require pict "digraph.rkt")

(provide (contract-out [er-diagram (-> list? list? pict?)]))

(define (er-diagram tables relations)
  (digraph->pict (er-diagram->digraph tables relations)))

(define (er-diagram->digraph tables relations)
  (define names (make-hash))
  (define vertices
    (for/list ([table (in-list tables)])
      (match table
        [(list (? string? title) (list (? string? fields) ...))
         (when (hash-has-key? names title)
           (raise-arguments-error 'er-diagram "duplicate table name" "name" title))
         (hash-set! names title #t)
         (list title '#:label (string-append "{" (record-text title) "|"
                                            (string-join (map record-text fields) "\\n") "}")
               '#:shape "record" '#:width "2")]
        [_ (raise-arguments-error 'er-diagram "expected a table name and field list"
                                   "table" table)])))
  (define edges
    (for/list ([relation (in-list relations)])
      (match relation
        [(list (? string? head) (? string? tail) tail-arity head-arity)
         (for ([name (in-list (list head tail))])
           (unless (hash-has-key? names name)
             (raise-arguments-error 'er-diagram "relation names an unknown table"
                                    "table" name "relation" relation)))
         (edge (list (endpoint head #f #f) (endpoint tail #f #f))
               (hash '#:dir "both" '#:arrowhead (arity-shape head-arity)
                     '#:arrowtail (arity-shape tail-arity)))]
        [_ (raise-arguments-error 'er-diagram "expected two table names and cardinalities"
                                   "relation" relation)])))
  (make-digraph (append vertices edges) #:splines "ortho"))

(define (record-text text)
  (list->string
   (append-map
    (lambda (char)
      (if (memv char '(#\\ #\{ #\} #\| #\< #\>)) (list #\\ char) (list char)))
    (string->list text))))

(define (arity-shape arity)
  (match arity
    [(or 'many (list 'quote 'many)) "crow"]
    [(or 'one (list 'quote 'one)) "none"]
    [_ (raise-argument-error 'er-diagram "'one or 'many cardinality" arity)]))

(module+ test-support
  (provide er-diagram->digraph))
