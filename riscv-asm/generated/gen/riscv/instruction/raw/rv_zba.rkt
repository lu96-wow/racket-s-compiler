#lang racket/base

(require "../../../../lib/base.rkt"
         "../../../../lib/riscv/raw/scalar.rkt"
         "../../../../lib/riscv/raw/compressed.rkt"
         "../../../../lib/riscv/raw/vector.rkt"
         "../../../../lib/riscv/raw/mop.rkt")

(define sh1add
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 25 31 16) (bit-range-fixed 12 14 2) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define sh2add
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 25 31 16) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define sh3add
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 25 31 16) (bit-range-fixed 12 14 6) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))

(provide
 sh1add
 sh2add
 sh3add)
