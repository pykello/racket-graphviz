#lang racket

(require rsvg)
(require pict)
(require "dot.rkt")

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

(define sample_graphs
  (list
   "digraph D {
     A [shape=diamond]
     B [shape=box]
     C [shape=circle]
     A -> B [style=dashed, color=grey]
     A -> C [color=\"black:invis:black\"]
     A -> D [penwidth=5, arrowhead=none]
   }"
   "digraph D {
     node [fontname=\"Arial\"];
     node_A [shape=record    label=\"shape=record|{above|middle|below}|right\"];
     node_B [shape=plaintext label=\"shape=plaintext|{curly|braces and|bars without}|effect\"];
   }"
   "digraph G {
     a b c d;
     subgraph cluster0 {
       a -> b;
       a -> c;
       b -> d;
       c -> d;
     }
     subgraph cluster1 {
       e -> g;
       e -> f;
     }
     b -> f [lhead=cluster1];
     d -> e;
     c -> g [ltail=cluster0,lhead=cluster1];
     c -> e [ltail=cluster0];
     d -> h;
   }"
   "digraph D {
     A -> {B, C, D} -> {F}
    }"
   "digraph G {
      subgraph cluster_0 {
        style=filled;
        color=lightgrey;
        node [style=filled,color=white];
        a0 -> a1 -> a2 -> a3;
        label = \"process #1\";
      }
      subgraph cluster_1 {
        node [style=filled];
        b0 -> b1 -> b2 -> b3;
        label = \"process #2\";
        color=blue;
      }
      start -> a0;
      start -> b0;
      a1 -> b3;
      b2 -> a3;
      a3 -> a0;
      a3 -> end;
      b3 -> end;
      start [shape=Mdiamond];
      end [shape=Msquare];
   }"
   ))

(define (side-by-side d)
  (define p1 (svg-port->pict (run-dot d "svg")))
  (define p2 (dot->pict d))
  (hc-append 10 p1 p2))

(side-by-side (first sample_graphs))
;;(map side-by-side sample_graphs)

(define d1 (make-digraph `(["a" #:shape "diamond"]
                           ["b" #:shape ,(cloud 70 20) #:label "stdout"]
                           "c" "d")
                         `("a -> b -> c"
                           "a -> d -> c")))

(define d1-dot (digraph->dot d1))
(display d1-dot)
(newline)

(define a-shape (cc-superimpose (cloud 80 40) (text "Hello!")))

(define d1-node-picts
  (make-hash `(["a" . ,a-shape])))

(dot->pict d1-dot #:node-picts d1-node-picts)
