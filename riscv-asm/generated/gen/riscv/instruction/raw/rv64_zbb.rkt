#lang racket/base

(require "../../../../lib/base.rkt"
         "../../../../lib/riscv/raw/scalar.rkt"
         "../../../../lib/riscv/raw/compressed.rkt"
         "../../../../lib/riscv/raw/vector.rkt"
         "../../../../lib/riscv/raw/mop.rkt")

(define clzw
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 20 31 1536) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 6) (bit-range-fixed 0 1 3))))
(define ctzw
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 20 31 1537) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 6) (bit-range-fixed 0 1 3))))
(define cpopw
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 20 31 1538) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 6) (bit-range-fixed 0 1 3))))
(define rolw
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 25 31 48) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 14) (bit-range-fixed 0 1 3))))
(define rorw
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 25 31 48) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 14) (bit-range-fixed 0 1 3))))
(define roriw
  (make-instruction
   (list rd rs1 shamtw)
   (list (bit-range-fixed 25 31 48) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 6) (bit-range-fixed 0 1 3))))
(define rori
  (make-instruction
   (list rd rs1 shamtd)
   (list (bit-range-fixed 26 31 24) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define rev8
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 20 31 1720) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 19))))
(define zext.h
  (make-instruction
   (list rd rs1)
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
