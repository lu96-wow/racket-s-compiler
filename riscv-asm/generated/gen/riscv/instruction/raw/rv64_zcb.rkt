#lang racket/base

(require "../../../../lib/base.rkt"
         "../../../../lib/riscv/raw/scalar.rkt"
         "../../../../lib/riscv/raw/compressed.rkt"
         "../../../../lib/riscv/raw/vector.rkt"
         "../../../../lib/riscv/raw/mop.rkt")

(define c.zext.w
  (make-instruction
   (list rd_rs1_p)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 4) (bit-range-fixed 10 12 7) (bit-range-fixed 5 6 3) (bit-range-fixed 2 4 4))))
(define c.sext.w
  (make-instruction
   (list rd_rs1_n0)
   (list (bit-range-fixed 13 15 1) (bit-range-fixed 12 12 0) (bit-range-fixed 2 6 0) (bit-range-fixed 0 1 1))))

(provide
 c.zext.w
 c.sext.w)
