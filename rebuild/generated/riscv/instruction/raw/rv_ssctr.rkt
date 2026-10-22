#lang racket/base

(require "../../../base.rkt"
         "../../raw/scalar.rkt"
         "../../raw/compressed.rkt"
         "../../raw/vector.rkt"
         "../../raw/mop.rkt")

(define sctrclr
  (make-instruction
   (list)
   (list (bit-range-fixed 7 11 0) (bit-range-fixed 15 19 0) (bit-range-fixed 20 31 260) (bit-range-fixed 12 14 0) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))

(provide
 sctrclr)
