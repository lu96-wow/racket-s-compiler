#lang racket/base

(require "../../../../lib/base.rkt"
         "../../../../lib/riscv/raw/scalar.rkt"
         "../../../../lib/riscv/raw/compressed.rkt"
         "../../../../lib/riscv/raw/vector.rkt"
         "../../../../lib/riscv/raw/mop.rkt")

(define aes32dsmi
  (make-instruction
   (list rd rs1 rs2 bs)
   (list (bit-range-fixed 25 29 23) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 51))))
(define aes32dsi
  (make-instruction
   (list rd rs1 rs2 bs)
   (list (bit-range-fixed 25 29 21) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 51))))

(provide
 aes32dsmi
 aes32dsi)
