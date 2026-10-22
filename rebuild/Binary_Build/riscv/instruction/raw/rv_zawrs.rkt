#lang racket/base

(require "../../../base.rkt"
         "../../raw/scalar.rkt"
         "../../raw/compressed.rkt"
         "../../raw/vector.rkt"
         "../../raw/mop.rkt")

(define wrs.nto
  (make-instruction
   (list)
   (list (bit-range-fixed 20 31 13) (bit-range-fixed 7 19 0) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define wrs.sto
  (make-instruction
   (list)
   (list (bit-range-fixed 20 31 29) (bit-range-fixed 7 19 0) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))

(provide
 wrs.nto
 wrs.sto)
