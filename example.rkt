#lang racket

(require pict)
(require "dot.rkt")
(require "digraph.rkt")

(define examples
  `(
    ;; graph 1
    (["A" #:shape "diamond"]
     ["B" #:shape "box"]
     ["C" #:shape "circle" #:width "1"]
     [("A" "B") #:style "dashed" #:color "grey"]
     [("A" "C") #:color "black:invis:black"]
     [("A" "D") #:penwidth "5" #:arrowhead "none"])
    ;; graph 2
    ([subgraph "process #1"
               #:style "filled"
               #:color "lightgrey"
               (
                "a0 -> a1 -> a2 -> a3"
               )]
     [subgraph "process #2"
               #:color "blue"
               (
                "b0 -> b1 -> b2 -> b3"
               )]
     "start -> a0"
     "start -> b0"
     "a1 -> b3"
     "b2 -> a3"
     "a3 -> a0"
     "a3 -> end"
     "b3 -> end"
     ["start" #:shape "Mdiamond"]
     ["end" #:shape "Msquare"]
    )))

(define d1 (make-digraph `(["a" #:shape "diamond" #:fillcolor "lightgray" #:style "filled"]
                           ["b" #:shape ,(cloud 60 30) #:label "c"]
                           ["c" #:shape ,(standard-fish 100 50 #:open-mouth #t #:color "Chartreuse")
                                #:label ""]
                           "d"
                           "a -> b -> c"
                           "a -> d -> c"
                           (subgraph "stdout" #:style "filled" #:fillcolor "cyan"
                                     (["f" #:shape ,(file-icon 50 60 "bisque")]
                                      "g"
                                      "f -> g"))
                           "d -> g")))

(digraph->pict d1)
(for/list ([d examples])
  (digraph->pict (make-digraph d)))
