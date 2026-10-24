#lang racket/base

(require "../../../../lib/base.rkt"
         (prefix-in raw: "../../../../lib/riscv/raw/scalar.rkt")
         (prefix-in raw: "../../../../lib/riscv/raw/compressed.rkt")
         (prefix-in raw: "../../../../lib/riscv/raw/vector.rkt")
         (prefix-in raw: "../../../../lib/riscv/raw/mop.rkt")
         (prefix-in rebuilt: "../../field/rebuilt/scalar.rkt")
         (prefix-in rebuilt: "../../field/rebuilt/compressed.rkt")
         (prefix-in rebuilt: "../../field/rebuilt/vector.rkt")
         (prefix-in rebuilt: "../../field/rebuilt/mop.rkt"))

(define sinval.vma
  (make-instruction
   (list raw:rs1 raw:rs2)
   (list (bit-range-fixed 7 11 0) (bit-range-fixed 25 31 11) (bit-range-fixed 12 14 0) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define sfence.w.inval
  (make-instruction
   (list)
   (list (bit-range-fixed 7 11 0) (bit-range-fixed 15 19 0) (bit-range-fixed 20 24 0) (bit-range-fixed 25 31 12) (bit-range-fixed 12 14 0) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define sfence.inval.ir
  (make-instruction
   (list)
   (list (bit-range-fixed 7 11 0) (bit-range-fixed 15 19 0) (bit-range-fixed 20 24 1) (bit-range-fixed 25 31 12) (bit-range-fixed 12 14 0) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))

(provide
 sinval.vma
 sfence.w.inval
 sfence.inval.ir)
