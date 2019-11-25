#lang info
(define collection "graphviz")
(define deps '("base"
               "pict-lib"
               "draw-lib"
               "metapict"))
(define build-deps '("scribble-lib"
                     "pict-doc"
                     "racket-doc"
                     "rackunit-lib"))
(define scribblings '(("scribblings/graphviz.scrbl" ())))
(define pkg-desc "The goal of this library is to make composition of Racket Pict and Graphviz Diagrams possible.")
(define version "0.0.2")
(define pkg-authors '(pykello))
