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

(define hlv.wu
  (make-instruction
   (list raw:rd raw:rs1)
   (list (bit-range-fixed 20 24 1) (bit-range-fixed 25 31 52) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define hlv.d
  (make-instruction
   (list raw:rd raw:rs1)
   (list (bit-range-fixed 20 24 0) (bit-range-fixed 25 31 54) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define hsv.d
  (make-instruction
   (list raw:rs1 raw:rs2)
   (list (bit-range-fixed 7 11 0) (bit-range-fixed 25 31 55) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))

(provide
 hlv.wu
 hlv.d
 hsv.d)
