#lang racket/base

(require "../../../../lib/base.rkt"
         "../../../../lib/riscv/raw/scalar.rkt"
         "../../../../lib/riscv/raw/compressed.rkt"
         "../../../../lib/riscv/raw/vector.rkt"
         "../../../../lib/riscv/raw/mop.rkt")

(define zip
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 25 31 4) (bit-range-fixed 20 24 15) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define unzip
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 25 31 4) (bit-range-fixed 20 24 15) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define rori.rv32
  (make-instruction
   (list rd rs1 shamtw)
   (list (bit-range-fixed 25 31 48) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define rev8.rv32
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 20 31 1688) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 19))))

(provide
 zip
 unzip
 rori.rv32
 rev8.rv32)
