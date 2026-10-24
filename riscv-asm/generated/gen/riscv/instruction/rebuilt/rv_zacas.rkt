#lang racket/base

(require "../../../../lib/base.rkt"
         (prefix-in raw: "../../../../lib/riscv/raw/scalar.rkt")
         (prefix-in raw: "../../../../lib/riscv/raw/compressed.rkt")
         (prefix-in raw: "../../../../lib/riscv/raw/vector.rkt")
         (prefix-in raw: "../../../../lib/riscv/raw/mop.rkt")
         (prefix-in rebuilt: "../../../../lib/riscv/rebuilt/scalar.rkt")
         (prefix-in rebuilt: "../../../../lib/riscv/rebuilt/compressed.rkt")
         (prefix-in rebuilt: "../../../../lib/riscv/rebuilt/vector.rkt")
         (prefix-in rebuilt: "../../../../lib/riscv/rebuilt/mop.rkt"))

(define amocas.w
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2 raw:aq raw:rl)
   (list (bit-range-fixed 29 31 1) (bit-range-fixed 27 28 1) (bit-range-fixed 12 14 2) (bit-range-fixed 2 6 11) (bit-range-fixed 0 1 3))))
(define amocas.d
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2 raw:aq raw:rl)
   (list (bit-range-fixed 29 31 1) (bit-range-fixed 27 28 1) (bit-range-fixed 12 14 3) (bit-range-fixed 2 6 11) (bit-range-fixed 0 1 3))))

(provide
 amocas.w
 amocas.d)
