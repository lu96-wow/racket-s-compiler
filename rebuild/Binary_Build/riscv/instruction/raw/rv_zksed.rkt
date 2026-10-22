#lang racket/base

(require "../../../base.rkt"
         "../../raw/scalar.rkt"
         "../../raw/compressed.rkt"
         "../../raw/vector.rkt"
         "../../raw/mop.rkt")

(define sm4ed
  (make-instruction
   (list rd rs1 rs2 bs)
   (list (bit-range-fixed 25 29 24) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 51))))
(define sm4ks
  (make-instruction
   (list rd rs1 rs2 bs)
   (list (bit-range-fixed 25 29 26) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 51))))

(provide
 sm4ed
 sm4ks)
