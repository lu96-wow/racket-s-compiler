#lang racket/base

(require "../../../base.rkt"
         "../../raw/scalar.rkt"
         "../../raw/compressed.rkt"
         "../../raw/vector.rkt"
         "../../raw/mop.rkt")

(define fmvh.x.d
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 20 24 1) (bit-range-fixed 27 31 28) (bit-range-fixed 12 14 0) (bit-range-fixed 25 26 1) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fmvp.d.x
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 27 31 22) (bit-range-fixed 12 14 0) (bit-range-fixed 25 26 1) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))

(provide
 fmvh.x.d
 fmvp.d.x)
