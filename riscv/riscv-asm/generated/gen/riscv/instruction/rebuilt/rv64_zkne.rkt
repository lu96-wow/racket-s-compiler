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

(define aes64esm
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 30 31 0) (bit-range-fixed 25 29 27) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 51))))
(define aes64es
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 30 31 0) (bit-range-fixed 25 29 25) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 51))))
(define aes64ks1i
  (make-instruction
   (list raw:rd raw:rs1 raw:rnum)
   (list (bit-range-fixed 30 31 0) (bit-range-fixed 25 29 24) (bit-range-fixed 24 24 1) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 19))))
(define aes64ks2
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 30 31 1) (bit-range-fixed 25 29 31) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 51))))

(provide
 aes64esm
 aes64es
 aes64ks1i
 aes64ks2)
