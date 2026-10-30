#lang racket/base

(require "../../../lib/info/struct.rkt")

(define rv_ssctr-instructions
  (list
   (instruction-info 'sctrclr 'rv_ssctr 32 4 '() '() '((7 11 0) (15 19 0) (20 31 260) (12 14 0) (2 6 28) (0 1 3)) '() (instruction-origin 'standard #f #f) '() '() "sctrclr")))

(provide
 rv_ssctr-instructions)
