#lang racket/base

(require "../../../../lib/base.rkt"
         "../../../../lib/riscv/raw/scalar.rkt"
         "../../../../lib/riscv/raw/compressed.rkt"
         "../../../../lib/riscv/raw/vector.rkt"
         "../../../../lib/riscv/raw/mop.rkt")

(define amocas.q
  (make-instruction
   (list rd rs1 rs2 aq rl)
   (list (bit-range-fixed 29 31 1) (bit-range-fixed 27 28 1) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 11) (bit-range-fixed 0 1 3))))

(provide
 amocas.q)
