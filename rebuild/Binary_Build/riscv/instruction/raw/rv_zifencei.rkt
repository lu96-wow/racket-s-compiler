#lang racket/base

(require "../../../base.rkt"
         "../../raw/scalar.rkt"
         "../../raw/compressed.rkt"
         "../../raw/vector.rkt"
         "../../raw/mop.rkt")

(define fence.i
  (make-instruction
   (list imm12 rs1 rd)
   (list (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 3) (bit-range-fixed 0 1 3))))

(provide
 fence.i)
