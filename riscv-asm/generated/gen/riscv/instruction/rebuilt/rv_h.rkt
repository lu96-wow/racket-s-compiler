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

(define hfence.vvma
  (make-instruction
   (list raw:rs1 raw:rs2)
   (list (bit-range-fixed 7 11 0) (bit-range-fixed 25 31 17) (bit-range-fixed 12 14 0) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define hfence.gvma
  (make-instruction
   (list raw:rs1 raw:rs2)
   (list (bit-range-fixed 7 11 0) (bit-range-fixed 25 31 49) (bit-range-fixed 12 14 0) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define hlv.b
  (make-instruction
   (list raw:rd raw:rs1)
   (list (bit-range-fixed 20 24 0) (bit-range-fixed 25 31 48) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define hlv.bu
  (make-instruction
   (list raw:rd raw:rs1)
   (list (bit-range-fixed 20 24 1) (bit-range-fixed 25 31 48) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define hlv.h
  (make-instruction
   (list raw:rd raw:rs1)
   (list (bit-range-fixed 20 24 0) (bit-range-fixed 25 31 50) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define hlv.hu
  (make-instruction
   (list raw:rd raw:rs1)
   (list (bit-range-fixed 20 24 1) (bit-range-fixed 25 31 50) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define hlvx.hu
  (make-instruction
   (list raw:rd raw:rs1)
   (list (bit-range-fixed 20 24 3) (bit-range-fixed 25 31 50) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define hlv.w
  (make-instruction
   (list raw:rd raw:rs1)
   (list (bit-range-fixed 20 24 0) (bit-range-fixed 25 31 52) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define hlvx.wu
  (make-instruction
   (list raw:rd raw:rs1)
   (list (bit-range-fixed 20 24 3) (bit-range-fixed 25 31 52) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define hsv.b
  (make-instruction
   (list raw:rs1 raw:rs2)
   (list (bit-range-fixed 7 11 0) (bit-range-fixed 25 31 49) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define hsv.h
  (make-instruction
   (list raw:rs1 raw:rs2)
   (list (bit-range-fixed 7 11 0) (bit-range-fixed 25 31 51) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define hsv.w
  (make-instruction
   (list raw:rs1 raw:rs2)
   (list (bit-range-fixed 7 11 0) (bit-range-fixed 25 31 53) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))

(provide
 hfence.vvma
 hfence.gvma
 hlv.b
 hlv.bu
 hlv.h
 hlv.hu
 hlvx.hu
 hlv.w
 hlvx.wu
 hsv.b
 hsv.h
 hsv.w)
