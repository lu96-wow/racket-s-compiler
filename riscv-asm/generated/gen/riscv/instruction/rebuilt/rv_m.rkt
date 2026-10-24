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

(define mul
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 25 31 1) (bit-range-fixed 12 14 0) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define mulh
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 25 31 1) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define mulhsu
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 25 31 1) (bit-range-fixed 12 14 2) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define mulhu
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 25 31 1) (bit-range-fixed 12 14 3) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define div
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 25 31 1) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define divu
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 25 31 1) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define rem
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 25 31 1) (bit-range-fixed 12 14 6) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define remu
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 25 31 1) (bit-range-fixed 12 14 7) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))

(provide
 mul
 mulh
 mulhsu
 mulhu
 div
 divu
 rem
 remu)
