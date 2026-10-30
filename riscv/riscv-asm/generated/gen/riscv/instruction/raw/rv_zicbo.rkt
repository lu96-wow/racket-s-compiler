#lang racket/base

(require "../../../../lib/base.rkt"
         "../../../../lib/riscv/raw/scalar.rkt"
         "../../../../lib/riscv/raw/compressed.rkt"
         "../../../../lib/riscv/raw/vector.rkt"
         "../../../../lib/riscv/raw/mop.rkt")

(define cbo.clean
  (make-instruction
   (list rs1)
   (list (bit-range-fixed 20 31 1) (bit-range-fixed 12 14 2) (bit-range-fixed 7 11 0) (bit-range-fixed 2 6 3) (bit-range-fixed 0 1 3))))
(define cbo.flush
  (make-instruction
   (list rs1)
   (list (bit-range-fixed 20 31 2) (bit-range-fixed 12 14 2) (bit-range-fixed 7 11 0) (bit-range-fixed 2 6 3) (bit-range-fixed 0 1 3))))
(define cbo.inval
  (make-instruction
   (list rs1)
   (list (bit-range-fixed 20 31 0) (bit-range-fixed 12 14 2) (bit-range-fixed 7 11 0) (bit-range-fixed 2 6 3) (bit-range-fixed 0 1 3))))
(define cbo.zero
  (make-instruction
   (list rs1)
   (list (bit-range-fixed 20 31 4) (bit-range-fixed 12 14 2) (bit-range-fixed 7 11 0) (bit-range-fixed 2 6 3) (bit-range-fixed 0 1 3))))
(define prefetch.i
  (make-instruction
   (list rs1 imm12hi)
   (list (bit-range-fixed 20 24 0) (bit-range-fixed 12 14 6) (bit-range-fixed 7 11 0) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define prefetch.r
  (make-instruction
   (list rs1 imm12hi)
   (list (bit-range-fixed 20 24 1) (bit-range-fixed 12 14 6) (bit-range-fixed 7 11 0) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define prefetch.w
  (make-instruction
   (list rs1 imm12hi)
   (list (bit-range-fixed 20 24 3) (bit-range-fixed 12 14 6) (bit-range-fixed 7 11 0) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))

(provide
 cbo.clean
 cbo.flush
 cbo.inval
 cbo.zero
 prefetch.i
 prefetch.r
 prefetch.w)
