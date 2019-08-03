#lang racket

(require pict
         racket/draw
         "../lib/dot.rkt"
         "../lib/digraph.rkt"
         "utils.rkt")

(define (main)
  (define depth (make-parameter 2))
  (define out-file (make-parameter "dirtree.svg"))

  (define path
    (command-line
     #:once-each
     [("-d" "--depth") "Directory tree depth" (depth 1)]
     [("-o" "--output") "Output SVG file name" (out-file "dirtree.svg")]
     #:args ([path-arg "."])
     path-arg))

  (define complete-path (simplify-path (path->complete-path path)))

  (define result-pict (digraph->pict (dirtree complete-path (depth))))
  (save-pict-as-svg result-pict (out-file)))

(define (dirtree path depth)
  (make-digraph (dirtree-defs path depth) #:ortho #f))

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
