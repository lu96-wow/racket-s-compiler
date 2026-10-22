#lang racket/base

(require "../../../base.rkt"
         "../../raw/scalar.rkt"
         "../../raw/compressed.rkt"
         "../../raw/vector.rkt"
         "../../raw/mop.rkt")

(define lpad
  (make-instruction
   (list imm20)
   (list (bit-range-fixed 7 11 0) (bit-range-fixed 2 6 5) (bit-range-fixed 0 1 3))))

(provide
 lpad)
