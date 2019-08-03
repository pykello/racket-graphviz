#lang racket

(require pict
         racket/draw)

(provide save-pict-as-svg)

(define (save-pict-as-svg p filename
                          [width (pict-width p)]
                          [height (pict-height p)]
                          [exists 'replace])
  (define dc (new svg-dc%
                  [width width]
                  [height height]
                  [output filename]
                  [exists exists]))
  (send dc start-doc "")
  (send dc start-page)
  (draw-pict p dc 0 0)
  (send dc end-page)
  (send dc end-doc))
