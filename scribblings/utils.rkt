#lang racket

(require "../main.rkt")

(provide digraph->pict-cached dot->pict-cached)

;; The documentation should build even on machines without Graphviz
;; installed (e.g. the package build service), so rendering failures
;; degrade to a placeholder instead of failing `raco setup`.
(define (diagram-placeholder why)
  (define first-line (car (string-split why "\n")))
  (define message
    (if (> (string-length first-line) 60)
        (string-append (substring first-line 0 57) "...")
        first-line))
  (define body (frame (text (format "diagram omitted: ~a" message))))
  ;; opaque background so the placeholder is legible in dark themes too
  (cc-superimpose
   (filled-rectangle (+ (pict-width body) 8) (+ (pict-height body) 8) #:color "white")
   body))

(define (digraph->pict-cached graph)
  (with-handlers ([exn:fail? (λ (e) (pict->bitmap (diagram-placeholder (exn-message e))))])
    (pict->bitmap (digraph->pict graph))))

(define (dot->pict-cached definition #:node-picts [node-picts (hash)])
  (with-handlers ([exn:fail? (λ (e) (pict->bitmap (diagram-placeholder (exn-message e))))])
    (pict->bitmap (dot->pict definition #:node-picts node-picts))))
