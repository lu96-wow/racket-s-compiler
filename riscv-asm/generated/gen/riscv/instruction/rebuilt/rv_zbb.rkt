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

(define andn
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 25 31 32) (bit-range-fixed 12 14 7) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define orn
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 25 31 32) (bit-range-fixed 12 14 6) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define xnor
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 25 31 32) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define clz
  (make-instruction
   (list raw:rd raw:rs1)
   (list (bit-range-fixed 20 31 1536) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define ctz
  (make-instruction
   (list raw:rd raw:rs1)
   (list (bit-range-fixed 20 31 1537) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define cpop
  (make-instruction
   (list raw:rd raw:rs1)
   (list (bit-range-fixed 20 31 1538) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define max
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 25 31 5) (bit-range-fixed 12 14 6) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define maxu
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 25 31 5) (bit-range-fixed 12 14 7) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define min
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 25 31 5) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define minu
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 25 31 5) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define sext.b
  (make-instruction
   (list raw:rd raw:rs1)
   (list (bit-range-fixed 20 31 1540) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define sext.h
  (make-instruction
   (list raw:rd raw:rs1)
   (list (bit-range-fixed 20 31 1541) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define rol
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 25 31 48) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define ror
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 25 31 48) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define orc.b
  (make-instruction
   (list raw:rd raw:rs1)
   (list (bit-range-fixed 20 31 647) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 19))))

(provide
 andn
 orn
 xnor
 clz
 ctz
 cpop
 max
 maxu
 min
 minu
 sext.b
 sext.h
 rol
 ror
 orc.b)
