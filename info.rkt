#lang info
(define collection "graphviz")
(define deps '("base"))
(define build-deps '("scribble-lib" "racket-doc" "rackunit-lib"))
(define scribblings '(("scribblings/graphviz.scrbl" ())))
(define pkg-desc "The goal of this library is to make composition of Racket Pict and Graphviz Diagrams possible.")
(define version "0.0")
(define pkg-authors '(pykello))
