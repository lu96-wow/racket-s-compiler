#lang racket/base

(require "../../../../lib/base.rkt"
         (prefix-in raw: "../../../../lib/riscv/raw/scalar.rkt")
         (prefix-in raw: "../../../../lib/riscv/raw/compressed.rkt")
         (prefix-in raw: "../../../../lib/riscv/raw/vector.rkt")
         (prefix-in raw: "../../../../lib/riscv/raw/mop.rkt")
         (prefix-in rebuilt: "../../../../lib/riscv/rebuilt/scalar.rkt")
         (prefix-in rebuilt: "../../../../lib/riscv/rebuilt/compressed.rkt")
         (prefix-in rebuilt: "../../../../lib/riscv/rebuilt/vector.rkt")
         (prefix-in rebuilt: "../../../../lib/riscv/rebuilt/mop.rkt"))

(define sha256sum0
  (make-instruction
   (list raw:rd raw:rs1)
   (list (bit-range-fixed 30 31 0) (bit-range-fixed 25 29 8) (bit-range-fixed 20 24 0) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 19))))
(define sha256sum1
  (make-instruction
   (list raw:rd raw:rs1)
   (list (bit-range-fixed 30 31 0) (bit-range-fixed 25 29 8) (bit-range-fixed 20 24 1) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 19))))
(define sha256sig0
  (make-instruction
   (list raw:rd raw:rs1)
   (list (bit-range-fixed 30 31 0) (bit-range-fixed 25 29 8) (bit-range-fixed 20 24 2) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 19))))
(define sha256sig1
  (make-instruction
   (list raw:rd raw:rs1)
   (list (bit-range-fixed 30 31 0) (bit-range-fixed 25 29 8) (bit-range-fixed 20 24 3) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 19))))

(provide
 sha256sum0
 sha256sum1
 sha256sig0
 sha256sig1)
