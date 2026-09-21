#lang racket
(require rackunit pict "../lib/erdiagram.rkt" "../lib/digraph.rkt"
         (submod "../lib/erdiagram.rkt" test-support))
(module+ test
  (define tables '(("a" ("id")) ("b" ("id"))))
  (for* ([head '(one many)] [tail '(one many)])
    (define normal (er-diagram->digraph tables (list (list "a" "b" head tail))))
    (define legacy
      (er-diagram->digraph tables (list (list "a" "b" (list 'quote head) (list 'quote tail)))))
    (check-equal? (digraph->dot normal) (digraph->dot legacy)))
  (check-exn #rx"duplicate table" (lambda () (er-diagram->digraph (append tables tables) '())))
  (check-exn #rx"unknown table" (lambda () (er-diagram->digraph tables '(("a" "c" one many)))))
  (check-exn #rx"cardinality" (lambda () (er-diagram->digraph tables '(("a" "b" invalid many)))))
  (when (find-executable-path "dot")
    (check-true (pict? (er-diagram tables '(("a" "b" one many)))))
    (check-true
     (pict? (er-diagram '(("a:b" ("{field}|<port>" "slash\\name")) ("b" ("id")))
                        '(("a:b" "b" one many)))))))
