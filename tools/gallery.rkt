#lang racket
(require file/convertible file/sha1 json racket/runtime-path
         "../main.rkt")
(define-runtime-path fixtures "../tests/fixtures")

(module+ main
  (define destination
    (command-line #:args ([destination "build/gallery"]) destination))
  (make-directory* destination)
  (define sources '("shapes" "labels" "large"))
  (define (write-artifact name data)
    (call-with-output-file (build-path destination name)
      (lambda (out) (write-bytes data out)) #:exists 'replace)
    (void))
  (for ([name (in-list sources)])
    (define dot (file->string (build-path fixtures (string-append name ".dot"))))
    (define picture (dot->pict dot))
    (for ([output-format '("svg" "png")])
      (define port (run-dot dot output-format))
      (define native (dynamic-wind void (lambda () (port->bytes port))
                                   (lambda () (close-input-port port))))
      (write-artifact (format "~a-native.~a" name output-format) native)
      (write-artifact (format "~a-pict.~a" name output-format)
                      (convert picture (if (equal? output-format "svg") 'svg-bytes 'png-bytes)))))
  (define custom
    (digraph->pict
     (make-digraph `(("a" #:label "" #:shape ,(colorize (disk 40) "red"))
                     ("b" #:label "" #:shape ,(standard-fish 80 40))
                     "a -> b"))))
  (write-artifact "custom.svg" (convert (rotate (scale custom 1.2) 0.2) 'svg-bytes))
  (define graphviz-version
    (with-output-to-string
      (lambda () (parameterize ([current-error-port (current-output-port)])
                   (system* (find-executable-path "dot") "-V")))))
  (define fonts
    (if (find-executable-path "fc-list")
        (with-output-to-string (lambda () (system* (find-executable-path "fc-list"))))
        "fc-list unavailable; record platform fonts separately"))
  (call-with-output-file (build-path destination "manifest.json")
    (lambda (out)
      (write-json
       (hash 'racket (version) 'platform (symbol->string (system-type))
             'graphviz graphviz-version 'fonts fonts
             'inputs (for/hash ([name (in-list sources)])
                       (values (string->symbol name)
                               (call-with-input-file
                                (build-path fixtures (string-append name ".dot")) sha1)))) out))
    #:exists 'replace)
  (call-with-output-file (build-path destination "index.html")
    (lambda (out)
      (display "<!doctype html><meta charset=\"utf-8\"><title>Graphviz comparison</title>" out)
      (for ([name (in-list sources)])
        (fprintf out "<h2>~a</h2><p>Native Graphviz / Racket pict</p><div style=\"display:flex;gap:20px\"><img style=\"width:48%;object-fit:contain\" src=\"~a-native.svg\"><img style=\"width:48%;object-fit:contain\" src=\"~a-pict.svg\"></div>" name name name))
      (display "<h2>Transformed custom pict nodes</h2><img src=\"custom.svg\">" out))
    #:exists 'replace))
