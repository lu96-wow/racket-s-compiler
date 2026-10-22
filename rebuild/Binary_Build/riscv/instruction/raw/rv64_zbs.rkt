#lang racket/base

(require "../../../base.rkt"
         "../../raw/scalar.rkt"
         "../../raw/compressed.rkt"
         "../../raw/vector.rkt"
         "../../raw/mop.rkt")

(define bclri
  (make-instruction
   (list rd rs1 shamtd)
   (list (bit-range-fixed 26 31 18) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define bexti
  (make-instruction
   (list rd rs1 shamtd)
   (list (bit-range-fixed 26 31 18) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define binvi
  (make-instruction
   (list rd rs1 shamtd)
   (list (bit-range-fixed 26 31 26) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define bseti
  (make-instruction
   (list rd rs1 shamtd)
   (list (bit-range-fixed 26 31 10) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))

(provide
 bclri
 bexti
 binvi
 bseti)
