#lang racket/base

(require "../../../../lib/base.rkt"
         "../../../../lib/riscv/raw/scalar.rkt"
         "../../../../lib/riscv/raw/compressed.rkt"
         "../../../../lib/riscv/raw/vector.rkt"
         "../../../../lib/riscv/raw/mop.rkt")

(define lpad
  (make-instruction
   (list imm20)
   (list (bit-range-fixed 7 11 0) (bit-range-fixed 2 6 5) (bit-range-fixed 0 1 3))))

(provide
 lpad)
