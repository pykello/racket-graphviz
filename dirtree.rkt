#lang racket

(require pict)
(require racket/draw)
(require "lib/dot.rkt")
(require "lib/digraph.rkt")

(define (dirtree path)
  (make-digraph (dirtree-defs path) #:ortho #f))

(define (dirtree-defs path)
  (let*-values
      ([(base name must-be-dir) (split-path path)]
       [(is-dir?)               (directory-exists? path)]
       [(label)                 (path->string name)]
       [(shape-width)           (+ 10 (text-width label))]
       [(color)                 (if is-dir? "cyan" "bisque")]
       [(shape)                 (file-icon shape-width 60 color)]
       [(root)                  (make-vertex label #:shape shape)]
       [(sub-defs)              (if is-dir?
                                    (subtree-defs root path)
                                    `())])
    (cons root sub-defs)))

(define (subtree-defs root-node root-path)
  (append*
   (for/list ([sub (directory-list root-path #:build? #t)])
     (define sub-defs (dirtree-defs (path->string sub)))
     (define sub-node (first sub-defs))
     (cons (make-edge root-node sub-node)
           sub-defs))))

(define text-size-dc (new bitmap-dc% [bitmap (make-object bitmap% 1 1)]))
(define (text-width s)
  (define-values (width height c d) (send text-size-dc get-text-extent s))
  (exact-round width))

(define d (dirtree "/home/hadi/sample"))
(define p (digraph->pict d))

p
