#lang racket
(require rackunit racket/runtime-path "../lib/digraph.rkt"
         (submod "../examples/dirtree.rkt" test-support))
(define-runtime-path root-example "../example.rkt")
(define-runtime-path er-example "../examples/erdiagram.rkt")
(module+ test
  (check-equal? (with-output-to-string (lambda () (dynamic-require root-example #f))) "")
  (check-equal? (with-output-to-string (lambda () (dynamic-require er-example #f))) "")
  (define directory (make-temporary-file "graphviz-tree~a" 'directory))
  (dynamic-wind
    void
    (lambda ()
      (make-directory (build-path directory "sub"))
      (check-equal? (length (digraph-objects (dirtree directory 0))) 1)
      (check-equal? (length (digraph-objects (dirtree directory 1))) 3)
      (check-exn exn:fail:contract? (lambda () (dirtree directory -1)))
      (check-exn exn:fail:contract? (lambda () (dirtree directory #f)))
      (check-true (digraph? (dirtree (simplify-path (build-path directory 'up)) 0)))
      (unless (eq? (system-type 'os) 'windows)
        (make-file-or-directory-link directory (build-path directory "sub" "loop"))
        (check-true (< (length (digraph-objects (dirtree directory 10))) 10))))
    (lambda () (delete-directory/files directory))))
