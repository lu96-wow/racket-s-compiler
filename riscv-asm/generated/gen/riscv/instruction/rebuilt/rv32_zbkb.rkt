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

(define zip
  (make-instruction
   (list raw:rd raw:rs1)
   (list (bit-range-fixed 25 31 4) (bit-range-fixed 20 24 15) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define unzip
  (make-instruction
   (list raw:rd raw:rs1)
   (list (bit-range-fixed 25 31 4) (bit-range-fixed 20 24 15) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define rev8.rv32
  (make-instruction
   (list raw:rd raw:rs1)
   (list (bit-range-fixed 20 31 1688) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 19))))
(define rori.rv32
  (make-instruction
   (list raw:rd raw:rs1 raw:shamtw)
   (list (bit-range-fixed 25 31 48) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))

(provide
 zip
 unzip
 rev8.rv32
 rori.rv32)
