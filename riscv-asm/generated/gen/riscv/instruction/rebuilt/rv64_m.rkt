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

(define mulw
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 25 31 1) (bit-range-fixed 12 14 0) (bit-range-fixed 2 6 14) (bit-range-fixed 0 1 3))))
(define divw
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 25 31 1) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 14) (bit-range-fixed 0 1 3))))
(define divuw
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 25 31 1) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 14) (bit-range-fixed 0 1 3))))
(define remw
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 25 31 1) (bit-range-fixed 12 14 6) (bit-range-fixed 2 6 14) (bit-range-fixed 0 1 3))))
(define remuw
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 25 31 1) (bit-range-fixed 12 14 7) (bit-range-fixed 2 6 14) (bit-range-fixed 0 1 3))))

(provide
 mulw
 divw
 divuw
 remw
 remuw)
