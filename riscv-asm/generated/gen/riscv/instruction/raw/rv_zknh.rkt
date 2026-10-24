#lang racket/base

(require "../../../../lib/base.rkt"
         "../../../../lib/riscv/raw/scalar.rkt"
         "../../../../lib/riscv/raw/compressed.rkt"
         "../../../../lib/riscv/raw/vector.rkt"
         "../../../../lib/riscv/raw/mop.rkt")

(define sha256sum0
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 30 31 0) (bit-range-fixed 25 29 8) (bit-range-fixed 20 24 0) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 19))))
(define sha256sum1
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 30 31 0) (bit-range-fixed 25 29 8) (bit-range-fixed 20 24 1) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 19))))
(define sha256sig0
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 30 31 0) (bit-range-fixed 25 29 8) (bit-range-fixed 20 24 2) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 19))))
(define sha256sig1
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 30 31 0) (bit-range-fixed 25 29 8) (bit-range-fixed 20 24 3) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 19))))

(provide
 sha256sum0
 sha256sum1
 sha256sig0
 sha256sig1)
