#lang racket

(require "private/process.rkt"
         pict
         json
         "private/render.rkt")

(provide current-dot-executable current-dot-timeout
         (contract-out
          [run-dot (-> string? string? port?)]
          [dot->pict (->* (string?) (#:node-picts hash?) pict?)]))

;;
;; converts the given dot definition to a pict
;;
(define (dot->pict str #:node-picts [node-picts (make-immutable-hash)])
  (define dot-output (run-dot str "json"))
  (define xdot-json
    (dynamic-wind void
                  (lambda () (read-json dot-output))
                  (lambda () (close-input-port dot-output))))
  (xdot-json->pict xdot-json node-picts))

