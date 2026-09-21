#lang racket/base

(require racket/file racket/port racket/string racket/system)

(provide current-dot-executable current-dot-timeout run-dot execute)

(define current-dot-executable
  (make-parameter
   #f
   (lambda (value)
     (unless (or (not value) (path-string? value))
       (raise-argument-error 'current-dot-executable "(or/c path-string? #f)" value))
     value)))

(define current-dot-timeout
  (make-parameter
   30
   (lambda (value)
     (unless (or (not value) (and (rational? value) (positive? value)))
       (raise-argument-error 'current-dot-timeout
                             "(or/c positive-finite-real? #f)" value))
     value)))

(define (resolve-dot)
  (define requested (current-dot-executable))
  (define executable
    (if requested
        (and (file-exists? requested) (path->complete-path requested))
        (find-executable-path "dot")))
  (unless executable
    (raise-arguments-error
     'run-dot
     "Graphviz executable not found; set current-dot-executable to its full path"
     "requested executable" (or requested "dot on PATH")))
  executable)

(define (limited-output in limit)
  (define out (open-output-bytes))
  (define buffer (make-bytes 4096))
  (let loop ([remaining limit])
    (define count (read-bytes-avail! buffer in))
    (unless (eof-object? count)
      (define retained (min remaining count))
      (write-bytes buffer out 0 retained)
      (loop (- remaining retained))))
  (get-output-bytes out))

(define (execute executable args input timeout)
  (define custodian (make-custodian))
  (define deadline
    (and timeout (+ (current-inexact-monotonic-milliseconds) (* 1000 timeout))))
  (define child #f)
  (define ports '())
  (define (await event)
    (define remaining
      (and deadline (max 0 (/ (- deadline (current-inexact-monotonic-milliseconds))
                              1000))))
    (unless (sync/timeout/enable-break remaining event)
      (error 'run-dot "Graphviz timed out after ~a seconds (~a)" timeout executable)))
  (dynamic-wind
    void
    (lambda ()
      (parameterize ([current-custodian custodian]
                     [current-subprocess-custodian-mode 'kill])
        (define-values (process stdout stdin stderr)
          (apply subprocess #f #f #f executable args))
        (set! child process)
        (set! ports (list stdout stdin stderr))
        (define (worker thunk)
          (define result (box #f))
          (define task
            (thread (lambda ()
                      (set-box! result (with-handlers ([exn? values]) (thunk))))))
          (cons task result))
        (define writer
          (worker (lambda ()
                    (write-string input stdin)
                    (newline stdin)
                    (close-output-port stdin))))
        (define reader (worker (lambda () (port->bytes stdout))))
        (define diagnostics (worker (lambda () (limited-output stderr 65536))))
        (await process)
        (for ([task (in-list (list writer reader diagnostics))])
          (await (thread-dead-evt (car task))))
        (define errors (unbox (cdr diagnostics)))
        (define message
          (if (bytes? errors) (bytes->string/utf-8 errors #\?) ""))
        (unless (zero? (subprocess-status process))
          (error 'run-dot "Graphviz exited with status ~a (~a): ~a~a"
                 (subprocess-status process) executable message
                 (if (and (member "-Tjson" args)
                          (regexp-match? #rx"not recognized" message))
                     "; install a Graphviz build supporting -Tjson" "")))
        (for ([task (in-list (list writer reader diagnostics))])
          (when (exn? (unbox (cdr task))) (raise (unbox (cdr task)))))
        (unless (string=? message "") (log-warning "Graphviz: ~a" message))
        (unbox (cdr reader))))
    (lambda ()
      (custodian-shutdown-all custodian)
      (when child (subprocess-wait child))
      (for ([port (in-list ports)])
        (unless (port-closed? port)
          (if (input-port? port) (close-input-port port) (close-output-port port)))))))

(define (run-dot input format)
  (unless (regexp-match? #px"^[A-Za-z0-9_]+(?::[A-Za-z0-9_]+){0,2}$" format)
    (raise-argument-error 'run-dot "Graphviz format[:renderer[:formatter]]" format))
  (open-input-bytes
   (execute (resolve-dot) (list "-y" (string-append "-T" format))
            input (current-dot-timeout))))
