#lang racket/base

(require "../../../../lib/base.rkt"
         "../../../../lib/riscv/raw/scalar.rkt"
         "../../../../lib/riscv/raw/compressed.rkt"
         "../../../../lib/riscv/raw/vector.rkt"
         "../../../../lib/riscv/raw/mop.rkt")

(define fence.i
  (make-instruction
   (list imm12 rs1 rd)
   (list (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 3) (bit-range-fixed 0 1 3))))

(provide
 fence.i)
