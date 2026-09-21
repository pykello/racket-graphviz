#lang racket/base


(require pict
         "lib/dot.rkt"
         "lib/digraph.rkt"
         "lib/erdiagram.rkt")

(provide (all-from-out pict)
         (all-from-out "lib/dot.rkt")
         (all-from-out "lib/digraph.rkt")
         (all-from-out "lib/erdiagram.rkt"))

(module+ test
  (require rackunit))

(module+ test
 (define examples
   `(
     (["A" #:shape "diamond"]
      ["B" #:shape "box"]
      ["C" #:shape "circle"]
      [("A" "B") #:style "dashed" #:color "grey"]
      [("A" "C") #:color "black:invis:black"]
      [("A" "D") #:penwidth "5" #:arrowhead "none"])
     ([subgraph "process #1"
                #:style "filled"
                #:color "lightgrey"
                ("a0 -> a1 -> a2 -> a3")]
      [subgraph "process #2"
                #:color "blue"
                ("b0 -> b1 -> b2 -> b3")]
      "start -> a0"
      "start -> b0"
      "a1 -> b3"
      "b2 -> a3"
      "a3 -> a0"
      "a3 -> end"
      "b3 -> end"
      ["start" #:shape "Mdiamond"]
      ["end" #:shape "Msquare"])
     (["a" #:shape "diamond" #:fillcolor "lightgray" #:style "filled"]
      ["b" #:shape ,(cloud 60 30) #:label "c"]
      ["c" #:shape ,(standard-fish 100 50 #:open-mouth #t #:color "Chartreuse")
           #:label ""]
      "d"
      "a -> b -> c"
      "a -> d -> c"
      (subgraph "stdout" #:style "filled" #:fillcolor "cyan"
                (["f" #:shape ,(file-icon 50 60 "bisque")]
                 "g"
                 "f -> g"))
      "d -> g")))

 (for/list ([d examples])
   (define result (digraph->pict (make-digraph d)))
   (check-true (pict? result))
   (check-true (positive? (pict-width result)))
   (check-true (positive? (pict-height result)))
   result))
  
  

(module+ main

  (require racket/cmdline)
  (define who (box "world"))
  (command-line
    #:program "my-program"
    #:once-each
    [("-n" "--name") name "Who to say hello to" (set-box! who name)]
    #:args ()
    (printf "hello ~a~n" (unbox who))))
