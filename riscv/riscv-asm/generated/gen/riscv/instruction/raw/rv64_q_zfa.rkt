#lang racket/base

(require "../../../../lib/base.rkt"
         "../../../../lib/riscv/raw/scalar.rkt"
         "../../../../lib/riscv/raw/compressed.rkt"
         "../../../../lib/riscv/raw/vector.rkt"
         "../../../../lib/riscv/raw/mop.rkt")

(define fmvh.x.q
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 20 24 1) (bit-range-fixed 27 31 28) (bit-range-fixed 12 14 0) (bit-range-fixed 25 26 3) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fmvp.q.x
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 27 31 22) (bit-range-fixed 12 14 0) (bit-range-fixed 25 26 3) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))

(provide
 fmvh.x.q
 fmvp.q.x)
