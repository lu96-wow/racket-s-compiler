#lang racket/base

(require "../../../base.rkt"
         "../../raw/scalar.rkt"
         "../../raw/compressed.rkt"
         "../../raw/vector.rkt"
         "../../raw/mop.rkt")

(define bclr
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 25 31 36) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define bext
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 25 31 36) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define binv
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 25 31 52) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define bset
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 25 31 20) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))

(provide
 bclr
 bext
 binv
 bset)
