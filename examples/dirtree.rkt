#lang racket

(require pict
         racket/draw
         file/convertible
         "../lib/dot.rkt"
         "../lib/digraph.rkt")

(define (main)
  (define depth (make-parameter 1))
  (define out-file (make-parameter "dirtree.svg"))

  (define path
    (command-line
     #:once-each
     [("-d" "--depth") d "directory tree depth" (depth (string->number d))]
     #:args ([path-arg "."])
     path-arg))

  (define complete-path (simplify-path (path->complete-path path)))
  (define d (dirtree complete-path (depth)))
  (define result-pict (digraph->pict d))
  (write-bytes (convert result-pict 'svg-bytes))
  (exit 0))

(define (dirtree path depth)
  (make-digraph (dirtree-defs path depth) #:splines "true"))

(define (dirtree-defs path depth)
  (let*-values
      ([(base name must-be-dir) (split-path path)]
       [(is-dir?)               (directory-exists? path)]
       [(label)                 (path->string name)]
       [(shape-width)           (+ 10 (text-width label))]
       [(color)                 (if is-dir? "cyan" "bisque")]
       [(shape)                 (file-icon shape-width 60 color)]
       [(root)                  (make-vertex label #:shape shape)]
       [(sub-defs)              (cond
                                  [(= depth 0) `()]
                                  [is-dir? (subtree-defs root path depth)]
                                  [else `()])])
    (cons root sub-defs)))

(define (subtree-defs root-node root-path depth)
  (append*
   (for/list ([sub (directory-list root-path #:build? #t)])
     (define sub-defs (dirtree-defs (path->string sub) (- depth 1)))
     (define sub-node (first sub-defs))
     (cons (make-edge root-node sub-node)
           sub-defs))))

(define text-size-dc (new bitmap-dc% [bitmap (make-object bitmap% 1 1)]))
(define (text-width s)
  (define-values (width height c d) (send text-size-dc get-text-extent s))
  (exact-round width))

(main)
