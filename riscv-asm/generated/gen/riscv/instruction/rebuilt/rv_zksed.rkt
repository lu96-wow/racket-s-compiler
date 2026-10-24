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

(define sm4ed
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2 raw:bs)
   (list (bit-range-fixed 25 29 24) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 51))))
(define sm4ks
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2 raw:bs)
   (list (bit-range-fixed 25 29 26) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 51))))

(provide
 sm4ed
 sm4ks)
