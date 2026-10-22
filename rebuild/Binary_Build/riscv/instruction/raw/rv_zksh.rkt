#lang racket/base

(require "../../../base.rkt"
         "../../raw/scalar.rkt"
         "../../raw/compressed.rkt"
         "../../raw/vector.rkt"
         "../../raw/mop.rkt")

(define sm3p0
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 30 31 0) (bit-range-fixed 25 29 8) (bit-range-fixed 20 24 8) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 19))))
(define sm3p1
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 30 31 0) (bit-range-fixed 25 29 8) (bit-range-fixed 20 24 9) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 19))))

(provide
 sm3p0
 sm3p1)
