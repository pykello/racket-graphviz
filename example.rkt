#lang racket

(require pict)
(require "dot.rkt")
(require "digraph.rkt")

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
