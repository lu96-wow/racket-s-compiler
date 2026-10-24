#lang racket/base

(require "../../../../lib/base.rkt"
         "../../../../lib/riscv/raw/scalar.rkt"
         "../../../../lib/riscv/raw/compressed.rkt"
         "../../../../lib/riscv/raw/vector.rkt"
         "../../../../lib/riscv/raw/mop.rkt")

(define fcvt.l.q
  (make-instruction
   (list rd rs1 rm)
   (list (bit-range-fixed 20 24 2) (bit-range-fixed 27 31 24) (bit-range-fixed 25 26 3) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fcvt.lu.q
  (make-instruction
   (list rd rs1 rm)
   (list (bit-range-fixed 20 24 3) (bit-range-fixed 27 31 24) (bit-range-fixed 25 26 3) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fcvt.q.l
  (make-instruction
   (list rd rs1 rm)
   (list (bit-range-fixed 20 24 2) (bit-range-fixed 27 31 26) (bit-range-fixed 25 26 3) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fcvt.q.lu
  (make-instruction
   (list rd rs1 rm)
   (list (bit-range-fixed 20 24 3) (bit-range-fixed 27 31 26) (bit-range-fixed 25 26 3) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))

(provide
 fcvt.l.q
 fcvt.lu.q
 fcvt.q.l
 fcvt.q.lu)
