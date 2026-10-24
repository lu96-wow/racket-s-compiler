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

(define aes32dsmi
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2 raw:bs)
   (list (bit-range-fixed 25 29 23) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 51))))
(define aes32dsi
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2 raw:bs)
   (list (bit-range-fixed 25 29 21) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 51))))

(provide
 aes32dsmi
 aes32dsi)
