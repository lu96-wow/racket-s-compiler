#lang racket/base

(require "../../../../lib/base.rkt"
         (prefix-in raw: "../../../../lib/riscv/raw/scalar.rkt")
         (prefix-in raw: "../../../../lib/riscv/raw/compressed.rkt")
         (prefix-in raw: "../../../../lib/riscv/raw/vector.rkt")
         (prefix-in raw: "../../../../lib/riscv/raw/mop.rkt")
         (prefix-in rebuilt: "../../field/rebuilt/scalar.rkt")
         (prefix-in rebuilt: "../../field/rebuilt/compressed.rkt")
         (prefix-in rebuilt: "../../field/rebuilt/vector.rkt")
         (prefix-in rebuilt: "../../field/rebuilt/mop.rkt"))

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
