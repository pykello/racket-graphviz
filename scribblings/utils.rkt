#lang racket

(require "../main.rkt")

(provide digraph->pict-cached dot->pict-cached)

(define (digraph->pict-cached graph)
  (pict->bitmap (digraph->pict graph)))

(define (dot->pict-cached definition #:node-picts [node-picts (hash)])
  (pict->bitmap (dot->pict definition #:node-picts node-picts)))
