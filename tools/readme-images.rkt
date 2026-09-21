#lang racket
(require file/convertible racket/runtime-path
         "../main.rkt" (submod "../example.rkt" test-support))
(define-runtime-path er-example "../examples/erdiagram.rkt")
(define-runtime-path tree-example "../examples/dirtree.rkt")
(define-runtime-path fixtures "../tests/fixtures")

(module+ main
  (define destination (command-line #:args ([destination "images"]) destination))
  (make-directory* destination)
  (call-with-output-file (build-path destination "custom-shapes.svg")
    (lambda (out)
      (void (write-bytes (convert (digraph->pict (make-digraph (last examples))) 'svg-bytes) out)))
    #:exists 'replace)
  (define (example-image name script . args)
    (call-with-output-file (build-path destination name)
      (lambda (out)
        (parameterize ([current-output-port out])
          (unless (apply system* (find-executable-path "racket") script args)
            (error 'readme-images "example failed: ~a" script))))
      #:exists 'replace))
  (example-image "erdiagram.svg" er-example)
  (example-image "dirtree.svg" tree-example "-d" "1" (path->string fixtures)))
