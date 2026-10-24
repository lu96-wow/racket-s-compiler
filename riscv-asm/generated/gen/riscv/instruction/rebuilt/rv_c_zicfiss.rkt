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

(define c.sspush.x1
  (make-instruction
   (list)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 2 6 0) (bit-range-fixed 7 11 1) (bit-range-fixed 12 12 0) (bit-range-fixed 13 15 3))))
(define c.sspopchk.x5
  (make-instruction
   (list)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 2 6 0) (bit-range-fixed 7 11 5) (bit-range-fixed 12 12 0) (bit-range-fixed 13 15 3))))

(provide
 c.sspush.x1
 c.sspopchk.x5)
