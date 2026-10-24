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

(define slli
  (make-instruction
   (list raw:rd raw:rs1 raw:shamtw)
   (list (bit-range-fixed 25 31 0) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define srli
  (make-instruction
   (list raw:rd raw:rs1 raw:shamtw)
   (list (bit-range-fixed 25 31 0) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define srai
  (make-instruction
   (list raw:rd raw:rs1 raw:shamtw)
   (list (bit-range-fixed 25 31 32) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define slli_rv32
  (make-instruction
   (list raw:rd raw:rs1 raw:shamtw)
   (list (bit-range-fixed 25 31 0) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define srli_rv32
  (make-instruction
   (list raw:rd raw:rs1 raw:shamtw)
   (list (bit-range-fixed 25 31 0) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define srai_rv32
  (make-instruction
   (list raw:rd raw:rs1 raw:shamtw)
   (list (bit-range-fixed 25 31 32) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))

(provide
 slli
 srli
 srai
 slli_rv32
 srli_rv32
 srai_rv32)
