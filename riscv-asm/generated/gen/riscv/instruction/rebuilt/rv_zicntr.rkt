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

(define rdcycle
  (make-instruction
   (list raw:rd)
   (list (bit-range-fixed 15 19 0) (bit-range-fixed 20 31 3072) (bit-range-fixed 12 14 2) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define rdtime
  (make-instruction
   (list raw:rd)
   (list (bit-range-fixed 15 19 0) (bit-range-fixed 20 31 3073) (bit-range-fixed 12 14 2) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define rdinstret
  (make-instruction
   (list raw:rd)
   (list (bit-range-fixed 15 19 0) (bit-range-fixed 20 31 3074) (bit-range-fixed 12 14 2) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))

(provide
 rdcycle
 rdtime
 rdinstret)
