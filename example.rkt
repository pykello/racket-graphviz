#lang racket

(require rsvg)
(require pict)
(require "dot.rkt")

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

(map side-by-side sample_graphs)

