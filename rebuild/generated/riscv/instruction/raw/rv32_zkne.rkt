#lang racket/base

(require "../../../base.rkt"
         "../../raw/scalar.rkt"
         "../../raw/compressed.rkt"
         "../../raw/vector.rkt"
         "../../raw/mop.rkt")

(define aes32esmi
  (make-instruction
   (list rd rs1 rs2 bs)
   (list (bit-range-fixed 25 29 19) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 51))))
(define aes32esi
  (make-instruction
   (list rd rs1 rs2 bs)
   (list (bit-range-fixed 25 29 17) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 51))))

(provide
 aes32esmi
 aes32esi)
