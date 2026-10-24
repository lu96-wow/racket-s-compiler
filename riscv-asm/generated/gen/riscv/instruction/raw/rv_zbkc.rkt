#lang racket/base

(require "../../../../lib/base.rkt"
         "../../../../lib/riscv/raw/scalar.rkt"
         "../../../../lib/riscv/raw/compressed.rkt"
         "../../../../lib/riscv/raw/vector.rkt"
         "../../../../lib/riscv/raw/mop.rkt")

(define clmul
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 25 31 5) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define clmulh
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 25 31 5) (bit-range-fixed 12 14 3) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))

(provide
 clmul
 clmulh)
