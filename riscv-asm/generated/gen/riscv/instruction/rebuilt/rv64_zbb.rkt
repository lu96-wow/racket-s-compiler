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

(define clzw
  (make-instruction
   (list raw:rd raw:rs1)
   (list (bit-range-fixed 20 31 1536) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 6) (bit-range-fixed 0 1 3))))
(define ctzw
  (make-instruction
   (list raw:rd raw:rs1)
   (list (bit-range-fixed 20 31 1537) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 6) (bit-range-fixed 0 1 3))))
(define cpopw
  (make-instruction
   (list raw:rd raw:rs1)
   (list (bit-range-fixed 20 31 1538) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 6) (bit-range-fixed 0 1 3))))
(define rolw
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 25 31 48) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 14) (bit-range-fixed 0 1 3))))
(define rorw
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 25 31 48) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 14) (bit-range-fixed 0 1 3))))
(define roriw
  (make-instruction
   (list raw:rd raw:rs1 raw:shamtw)
   (list (bit-range-fixed 25 31 48) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 6) (bit-range-fixed 0 1 3))))
(define rori
  (make-instruction
   (list raw:rd raw:rs1 raw:shamtd)
   (list (bit-range-fixed 26 31 24) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define rev8
  (make-instruction
   (list raw:rd raw:rs1)
   (list (bit-range-fixed 20 31 1720) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 19))))
(define zext.h
  (make-instruction
   (list raw:rd raw:rs1)
   (list (bit-range-fixed 25 31 4) (bit-range-fixed 20 24 0) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 14) (bit-range-fixed 0 1 3))))

(provide
 clzw
 ctzw
 cpopw
 rolw
 rorw
 roriw
 rori
 rev8
 zext.h)
