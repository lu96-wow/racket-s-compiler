#lang racket/base

(require "../../../../lib/base.rkt"
         "../../../../lib/riscv/raw/scalar.rkt"
         "../../../../lib/riscv/raw/compressed.rkt"
         "../../../../lib/riscv/raw/vector.rkt"
         "../../../../lib/riscv/raw/mop.rkt")

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
