#lang racket/base

(require "../../../../lib/base.rkt"
         "../../../../lib/riscv/raw/scalar.rkt"
         "../../../../lib/riscv/raw/compressed.rkt"
         "../../../../lib/riscv/raw/vector.rkt"
         "../../../../lib/riscv/raw/mop.rkt")

(define bclri.rv32
  (make-instruction
   (list rd rs1 shamtw)
   (list (bit-range-fixed 25 31 36) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define bexti.rv32
  (make-instruction
   (list rd rs1 shamtw)
   (list (bit-range-fixed 25 31 36) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define binvi.rv32
  (make-instruction
   (list rd rs1 shamtw)
   (list (bit-range-fixed 25 31 52) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define bseti.rv32
  (make-instruction
   (list rd rs1 shamtw)
   (list (bit-range-fixed 25 31 20) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))

(provide
 bclri.rv32
 bexti.rv32
 binvi.rv32
 bseti.rv32)
