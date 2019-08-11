#lang racket

(require graphviz
         file/sha1
         racket/draw
         file/convertible)

(provide digraph->pict-cached
          dot->pict-cached)

(define (digraph->pict-cached d)
  (dot->pict-cached (digraph->dot d)
             #:node-picts (digraph-node-picts d)))

(define (dot->pict-cached s #:node-picts [node-picts (make-hash)])
  (let*
      ([hash (sha1 (open-input-string (normalize-dot s)))]
       [filename (string-append hash ".png")]
       [path (build-path (current-directory) "images" filename)])
    (cond
      [(not (file-exists? path))
        (save-pict (dot->pict s #:node-picts node-picts) path)]
      [else 0])
    (define port (open-input-file path))
    (define result (read-bitmap port))
    (close-input-port port)
    result))

(define (save-pict pic path)
  (define port (open-output-file path))
  (write-bytes (convert pic 'png-bytes) port)
  (close-output-port port))

(define (normalize-dot s)
  (define s1 (string-replace s #rx" |\t" ""))
  (define s2 (string-replace s1 #rx"cluster_[0-9]+" "cluster_xxxx"))
  s2)
