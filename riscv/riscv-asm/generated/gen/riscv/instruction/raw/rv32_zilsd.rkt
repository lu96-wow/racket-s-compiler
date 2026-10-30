#lang racket/base

(require "../../../../lib/base.rkt"
         "../../../../lib/riscv/raw/scalar.rkt"
         "../../../../lib/riscv/raw/compressed.rkt"
         "../../../../lib/riscv/raw/vector.rkt"
         "../../../../lib/riscv/raw/mop.rkt")

(define ld
  (make-instruction
   (list rd_e rs1 imm12)
   (list (bit-range-fixed 12 14 3) (bit-range-fixed 2 7 0) (bit-range-fixed 0 1 3))))

(provide
 ld)
