#lang racket/base

(require "../../../lib/info/struct.rkt")

(define rv_sdext-instructions
  (list
   (instruction-info 'dret 'rv_sdext 32 4 '() '() '((7 11 0) (15 19 0) (20 31 1970) (12 14 0) (2 6 28) (0 1 3)) '() (instruction-origin 'standard #f #f) '() '() "dret")))

(provide
 rv_sdext-instructions)
