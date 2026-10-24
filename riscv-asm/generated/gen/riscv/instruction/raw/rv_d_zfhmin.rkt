#lang racket/base

(require "../../../../lib/base.rkt"
         "../../../../lib/riscv/raw/scalar.rkt"
         "../../../../lib/riscv/raw/compressed.rkt"
         "../../../../lib/riscv/raw/vector.rkt"
         "../../../../lib/riscv/raw/mop.rkt")

(define fcvt.d.h
  (make-instruction
   (list rd rs1 rm)
   (list (bit-range-fixed 20 24 2) (bit-range-fixed 27 31 8) (bit-range-fixed 25 26 1) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fcvt.h.d
  (make-instruction
   (list rd rs1 rm)
   (list (bit-range-fixed 20 24 1) (bit-range-fixed 27 31 8) (bit-range-fixed 25 26 2) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))

(provide
 fcvt.d.h
 fcvt.h.d)
