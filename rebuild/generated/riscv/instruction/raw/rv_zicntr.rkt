#lang racket/base

(require "../../../base.rkt"
         "../../raw/scalar.rkt"
         "../../raw/compressed.rkt"
         "../../raw/vector.rkt"
         "../../raw/mop.rkt")

(define rdcycle
  (make-instruction
   (list rd)
   (list (bit-range-fixed 15 19 0) (bit-range-fixed 20 31 3072) (bit-range-fixed 12 14 2) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define rdtime
  (make-instruction
   (list rd)
   (list (bit-range-fixed 15 19 0) (bit-range-fixed 20 31 3073) (bit-range-fixed 12 14 2) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define rdinstret
  (make-instruction
   (list rd)
   (list (bit-range-fixed 15 19 0) (bit-range-fixed 20 31 3074) (bit-range-fixed 12 14 2) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))

(provide
 rdcycle
 rdtime
 rdinstret)
