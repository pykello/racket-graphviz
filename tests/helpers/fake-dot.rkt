#lang racket/base
(require racket/port)
(module+ main
  (case (string->symbol (vector-ref (current-command-line-arguments) 0))
    [(binary) (write-bytes #"\0\377\200PNG") (void)]
    [(unicode)
     (for ([byte (in-bytes (string->bytes/utf-8 "λ魚"))])
       (write-byte byte) (flush-output) (sleep 0.01))]
    [(flood)
     (write-bytes (make-bytes 200000 65) (current-error-port))
     (write-bytes (make-bytes 200000 66))
     (port->bytes (current-input-port)) (void)]
    [(error) (display "failure" (current-error-port)) (exit 7)]
    [(sleep) (sleep 60)]))
