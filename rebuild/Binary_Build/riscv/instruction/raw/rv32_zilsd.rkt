#lang racket/base

(require "../../../base.rkt"
         "../../raw/scalar.rkt"
         "../../raw/compressed.rkt"
         "../../raw/vector.rkt"
         "../../raw/mop.rkt")

(define ld
  (make-instruction
   (list rd_e rs1 imm12)
   (list (bit-range-fixed 12 14 3) (bit-range-fixed 2 7 0) (bit-range-fixed 0 1 3))))

(provide
 ld)
