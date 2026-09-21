#lang racket

(require "dot.rkt" pict)

(provide (contract-out
          [make-vertex (->* (string?) (#:shape (or/c pict? string?)) vertex?)]
          [make-edge (-> vertex? vertex? edge?)]
          [digraph->dot (-> digraph? string?)]
          [digraph->pict (-> digraph? pict?)]
          [digraph-node-picts (-> digraph? hash?)])
         make-digraph digraph-ortho
         (struct-out digraph) (struct-out vertex) (struct-out edge)
         (struct-out subgraph) (struct-out endpoint))

(struct digraph (objects attrs))
(struct vertex (name label shape attrs))
(struct edge (nodes attrs))
(struct subgraph (label objects attrs))
(struct endpoint (name port compass) #:transparent)

(define default-shape "none")
(define current-node-names (make-parameter (hash)))

(define (node-name value)
  (hash-ref (current-node-names) value value))

(define (node-name-map graph)
  (define names (mutable-set))
  (define (record-endpoint value)
    (set-add! names (if (endpoint? value) (endpoint-name value)
                       (car (string-split value ":" #:trim? #f)))))
  (define (visit object)
    (match object
      [(vertex name _ _ _) (set-add! names name)]
      [(edge nodes _) (for-each record-endpoint nodes)]
      [(subgraph _ objects _) (for-each visit objects)]
      [(? list? nodes) (for-each record-endpoint nodes)]))
  (for-each visit (digraph-objects graph))
  (define result (make-hash))
  (define counter 0)
  (for ([name (in-list (sort (set->list names) string<?))]
        #:when (regexp-match? #px"\\\\(?:[\"\n]|$)" name))
    (define replacement
      (let loop ()
        (define candidate (format "__racket_graphviz_node_~a" counter))
        (set! counter (add1 counter))
        (if (set-member? names candidate) (loop) candidate)))
    (set-add! names replacement)
    (hash-set! result name replacement))
  result)

(define (make-vertex label #:shape [shape default-shape])
  (vertex (symbol->string (gensym 'n_)) label shape (hash)))

(define (make-edge n1 n2)
  (edge (list (vertex-name n1) (vertex-name n2)) (hash)))

(define (invalid value message)
  (raise-arguments-error 'make-digraph message "definition" value))

(define (attribute-value? value)
  (or (string? value) (boolean? value) (rational? value)))

(define (validate-attrs attrs)
  (unless (hash? attrs) (invalid attrs "expected an attribute hash"))
  (for ([(key value) (in-hash attrs)])
    (unless (and (keyword? key)
                 (regexp-match? #px"^[A-Za-z_][A-Za-z_0-9]*$" (keyword->string key)))
      (invalid key "expected a Graphviz attribute keyword"))
    (unless (attribute-value? value)
      (invalid value "expected a string, boolean, or finite real attribute value"))))

(define (valid-endpoint? value)
  (or (string? value)
      (and (endpoint? value) (string? (endpoint-name value))
           (or (not (endpoint-port value)) (string? (endpoint-port value)))
           (or (not (endpoint-compass value))
               (member (endpoint-compass value)
                       '("n" "ne" "e" "se" "s" "sw" "w" "nw" "c" "_"))))))

(define (validate-object object)
  (match object
    [(vertex name label shape attrs)
     (unless (and (string? name) (string? label) (or (string? shape) (pict? shape)))
       (invalid object "invalid vertex name, label, or shape"))
     (validate-attrs attrs)]
    [(edge nodes attrs)
     (unless (and (list? nodes) (>= (length nodes) 2) (andmap valid-endpoint? nodes))
       (invalid object "an edge needs at least two string or endpoint nodes"))
     (validate-attrs attrs)]
    [(subgraph label objects attrs)
     (unless (and (string? label) (list? objects))
       (invalid object "expected a subgraph label and object list"))
     (for-each validate-object objects)
     (validate-attrs attrs)]
    [(? list? nodes)
     (unless (and (pair? nodes) (andmap valid-endpoint? nodes))
       (invalid nodes "same-rank needs at least one node"))]
    [_ (invalid object "expected a vertex, edge, subgraph, or same-rank group")]))

(define (validate-graph graph)
  (unless (list? (digraph-objects graph))
    (invalid graph "expected a graph object list"))
  (normalize-graph-attrs (digraph-attrs graph))
  (for-each validate-object (digraph-objects graph)))

(define (normalize-graph-attrs attrs)
  (define normalized
    (if (boolean? attrs) (hash '#:splines (if attrs "ortho" "true")) attrs))
  (validate-attrs normalized)
  (cond
    [(hash-has-key? normalized '#:ortho)
     (define ortho (hash-ref normalized '#:ortho))
     (unless (boolean? ortho) (invalid ortho "#:ortho expects a boolean"))
     (define splines (if ortho "ortho" "true"))
     (when (and (hash-has-key? normalized '#:splines)
                (not (equal? splines (value->string (hash-ref normalized '#:splines)))))
       (invalid normalized "#:ortho and #:splines conflict"))
     (hash-set (hash-remove normalized '#:ortho) '#:splines splines)]
    [else normalized]))

(define (digraph-ortho graph)
  (equal? (hash-ref (normalize-graph-attrs (digraph-attrs graph)) '#:splines #f)
          "ortho"))

(define make-digraph
  (make-keyword-procedure
   (lambda (keywords values . arguments)
     (unless (and (= (length arguments) 1) (list? (car arguments)))
       (raise-arguments-error 'make-digraph "expected exactly one definitions list"
                              "arguments" arguments))
     (define attrs (normalize-graph-attrs (make-immutable-hash (map cons keywords values))))
     (validate-attrs attrs)
     (define graph (digraph (map make-object (car arguments)) attrs))
     (validate-graph graph)
     graph)))

(define (list->attrs arguments)
  (let loop ([remaining arguments] [attrs (hash)] [rest '()])
    (cond
      [(null? remaining) (values attrs (reverse rest))]
      [(keyword? (car remaining))
       (unless (and (pair? (cdr remaining)) (not (keyword? (cadr remaining))))
         (invalid remaining "attribute keyword needs a value"))
       (loop (cddr remaining)
             (if (hash-has-key? attrs (car remaining)) attrs
                 (hash-set attrs (car remaining) (cadr remaining))) rest)]
      [else (loop (cdr remaining) attrs (cons (car remaining) rest))])))


(define (make-object definition)
  (cond
    [(or (vertex? definition) (edge? definition) (subgraph? definition)) definition]
    [(string? definition)
     (if (string-contains? definition "->")
         (let ([nodes (map string-trim (string-split definition "->" #:trim? #f))])
           (when (ormap (lambda (name) (string=? name "")) nodes)
             (invalid definition "edge chain contains an empty node"))
           (edge nodes (hash)))
         (vertex definition definition default-shape (hash)))]
    [(and (list? definition) (pair? definition))
     (match definition
       [(list* 'same-rank nodes) nodes]
       [(list* 'subgraph rest)
        (define-values (attrs positional) (list->attrs rest))
        (match positional
          [(list (? string? label) (? list? definitions))
           (subgraph label (map make-object definitions) attrs)]
          [_ (invalid definition "subgraph needs a label and definitions list")])]
       [(list* 'edge rest) (make-list-edge rest definition)]
       [(list* (? list?) _) (make-list-edge definition definition)]
       [(list* (? string? name) rest)
        (define-values (attrs positional) (list->attrs rest))
        (unless (null? positional) (invalid definition "unexpected vertex arguments"))
        (vertex name (hash-ref attrs '#:label name)
                (hash-ref attrs '#:shape default-shape)
                (hash-remove (hash-remove attrs '#:label) '#:shape))]
       [_ (invalid definition "unrecognized graph definition")])]
    [else (invalid definition "unrecognized graph definition")]))

(define (make-list-edge rest definition)
  (unless (and (pair? rest) (list? (car rest)))
    (invalid definition "edge needs a node list"))
  (define-values (attrs positional) (list->attrs (cdr rest)))
  (unless (null? positional) (invalid definition "unexpected edge arguments"))
  (edge (car rest) attrs))

(define (vertices objects)
  (append-map (lambda (object)
                (cond [(vertex? object) (list object)]
                      [(subgraph? object) (vertices (subgraph-objects object))]
                      [else '()])) objects))

(define (digraph-node-picts graph)
  (validate-graph graph)
  (define result (make-hash))
  (define names (node-name-map graph))
  (for ([node (in-list (vertices (digraph-objects graph)))])
    (when (pict? (vertex-shape node))
      (define old (hash-ref result (hash-ref names (vertex-name node) (vertex-name node)) #f))
      (when (and old (not (eq? old (vertex-shape node))))
        (invalid (vertex-name node) "conflicting custom picts for one node"))
      (hash-set! result (hash-ref names (vertex-name node) (vertex-name node))
                 (vertex-shape node))))
  result)

(define (digraph->pict graph)
  (dot->pict (digraph->dot graph) #:node-picts (digraph-node-picts graph)))

(define (value->string value)
  (cond [(eq? value #t) "true"] [(eq? value #f) "false"]
        [(rational? value) (number->string (if (integer? value) value (exact->inexact value)))]
        [else value]))

(define (quote-id text)
  (string-append "\""
                 (string-replace text "\"" "\\\"")
                 "\""))

(define (quote-value text)
  (define output (open-output-string))
  (write-char #\" output)
  (let loop ([characters (string->list text)])
    (match characters
      ['() (void)]
      [(list #\\) (display "\\\\" output)]
      [(list* #\\ next rest)
       (write-char #\\ output)
       (write-char next output)
       (loop rest)]
      [(cons #\" rest) (display "\\\"" output) (loop rest)]
      [(cons char rest) (write-char char output) (loop rest)]))
  (write-char #\" output)
  (get-output-string output))

(define (endpoint->dot value)
  (cond
    [(endpoint? value)
     (string-append
      (quote-id (node-name (endpoint-name value)))
      (if (endpoint-port value) (string-append ":" (quote-id (endpoint-port value))) "")
      (if (endpoint-compass value) (string-append ":" (endpoint-compass value)) ""))]
    [else
     (define parts (string-split value ":" #:trim? #f))
     (string-join (map quote-id (cons (node-name (car parts)) (cdr parts))) ":")]))

(define (attribute-pairs attrs)
  (sort (hash->list attrs) keyword<? #:key car))

(define (property->string pair)
  (string-append (keyword->string (car pair)) "="
                 (quote-value (value->string (cdr pair)))))

(define (properties->string pairs)
  (string-append "[" (string-join (map property->string pairs) ",") "]"))

(define (digraph->dot graph)
  (validate-graph graph)
  (define cluster-index 0)
  (define (objects->dot objects)
    (string-join (map object->dot objects) "\n"))
  (define (object->dot object)
    (match object
      [(vertex name label shape attrs)
       (define custom? (pict? shape))
       (define properties
         (append (list (cons '#:label label)
                       (cons '#:shape (if custom? default-shape shape)))
                 (if custom?
                     (list (cons '#:fixedsize #t)
                           (cons '#:width (/ (pict-width shape) 72.0))
                           (cons '#:height (/ (pict-height shape) 72.0))) '())
                 (attribute-pairs attrs)))
       (string-append (quote-id (node-name name)) (properties->string properties))]
      [(edge nodes attrs)
       (string-append (string-join (map endpoint->dot nodes) " -> ")
                      (properties->string (attribute-pairs attrs)))]
      [(subgraph label objects attrs)
       (define id cluster-index)
       (set! cluster-index (add1 cluster-index))
       (format "subgraph cluster_~a {\nlabel=~a\n~a\n~a\n}"
               id (quote-value label)
               (string-join (map property->string (attribute-pairs attrs)) "\n")
               (objects->dot objects))]
      [(? list? nodes)
       (define names (map endpoint->dot nodes))
       (string-append "{rank=same; ordering=out;\n" (string-join names ";\n")
                      (if (> (length names) 1)
                          (string-append ";\n" (string-join names " -> ") "[style=invis]") "")
                      "\n}")]))
  (parameterize ([current-node-names (node-name-map graph)])
    (string-append "digraph {\n"
                 (string-join (map property->string (attribute-pairs (normalize-graph-attrs (digraph-attrs graph)))) "\n")
                 "\n" (objects->dot (digraph-objects graph)) "\n}")))
