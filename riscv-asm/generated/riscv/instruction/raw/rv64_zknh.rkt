#lang racket/base

(require "../../../base.rkt"
         "../../raw/scalar.rkt"
         "../../raw/compressed.rkt"
         "../../raw/vector.rkt"
         "../../raw/mop.rkt")

(define sha512sum0
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 30 31 0) (bit-range-fixed 25 29 8) (bit-range-fixed 20 24 4) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 19))))
(define sha512sum1
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 30 31 0) (bit-range-fixed 25 29 8) (bit-range-fixed 20 24 5) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 19))))
(define sha512sig0
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 30 31 0) (bit-range-fixed 25 29 8) (bit-range-fixed 20 24 6) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 19))))
(define sha512sig1
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 30 31 0) (bit-range-fixed 25 29 8) (bit-range-fixed 20 24 7) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 19))))

(provide
 sha512sum0
 sha512sum1
 sha512sig0
 sha512sig1)
