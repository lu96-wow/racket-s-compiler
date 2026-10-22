#lang racket/base

(require "../../../base.rkt"
         "../../raw/scalar.rkt"
         "../../raw/compressed.rkt"
         "../../raw/vector.rkt"
         "../../raw/mop.rkt")

(define hlv.wu
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 20 24 1) (bit-range-fixed 25 31 52) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define hlv.d
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 20 24 0) (bit-range-fixed 25 31 54) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define hsv.d
  (make-instruction
   (list rs1 rs2)
   (list (bit-range-fixed 7 11 0) (bit-range-fixed 25 31 55) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))

(provide
 hlv.wu
 hlv.d
 hsv.d)
