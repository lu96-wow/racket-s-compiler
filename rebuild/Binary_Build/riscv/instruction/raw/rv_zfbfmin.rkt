#lang racket/base

(require "../../../base.rkt"
         "../../raw/scalar.rkt"
         "../../raw/compressed.rkt"
         "../../raw/vector.rkt"
         "../../raw/mop.rkt")

(define fcvt.bf16.s
  (make-instruction
   (list rd rs1 rm)
   (list (bit-range-fixed 20 24 8) (bit-range-fixed 27 31 8) (bit-range-fixed 25 26 2) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fcvt.s.bf16
  (make-instruction
   (list rd rs1 rm)
   (list (bit-range-fixed 20 24 6) (bit-range-fixed 27 31 8) (bit-range-fixed 25 26 0) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))

(provide
 fcvt.bf16.s
 fcvt.s.bf16)
