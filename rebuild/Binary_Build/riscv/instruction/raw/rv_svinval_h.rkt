#lang racket/base

(require "../../../base.rkt"
         "../../raw/scalar.rkt"
         "../../raw/compressed.rkt"
         "../../raw/vector.rkt"
         "../../raw/mop.rkt")

(define hinval.vvma
  (make-instruction
   (list rs1 rs2)
   (list (bit-range-fixed 7 11 0) (bit-range-fixed 25 31 19) (bit-range-fixed 12 14 0) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define hinval.gvma
  (make-instruction
   (list rs1 rs2)
   (list (bit-range-fixed 7 11 0) (bit-range-fixed 25 31 51) (bit-range-fixed 12 14 0) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))

(provide
 hinval.vvma
 hinval.gvma)
