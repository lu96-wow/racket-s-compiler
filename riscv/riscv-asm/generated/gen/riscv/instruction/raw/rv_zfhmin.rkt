#lang racket/base

(require "../../../../lib/base.rkt"
         "../../../../lib/riscv/raw/scalar.rkt"
         "../../../../lib/riscv/raw/compressed.rkt"
         "../../../../lib/riscv/raw/vector.rkt"
         "../../../../lib/riscv/raw/mop.rkt")

(define flh
  (make-instruction
   (list rd rs1 imm12)
   (list (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 1) (bit-range-fixed 0 1 3))))
(define fsh
  (make-instruction
   (list imm12hi rs1 rs2 imm12lo)
   (list (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 9) (bit-range-fixed 0 1 3))))
(define fcvt.s.h
  (make-instruction
   (list rd rs1 rm)
   (list (bit-range-fixed 20 24 2) (bit-range-fixed 27 31 8) (bit-range-fixed 25 26 0) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fcvt.h.s
  (make-instruction
   (list rd rs1 rm)
   (list (bit-range-fixed 20 24 0) (bit-range-fixed 27 31 8) (bit-range-fixed 25 26 2) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fmv.x.h
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 20 24 0) (bit-range-fixed 27 31 28) (bit-range-fixed 12 14 0) (bit-range-fixed 25 26 2) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fmv.h.x
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 20 24 0) (bit-range-fixed 27 31 30) (bit-range-fixed 12 14 0) (bit-range-fixed 25 26 2) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))

(provide
 flh
 fsh
 fcvt.s.h
 fcvt.h.s
 fmv.x.h
 fmv.h.x)
