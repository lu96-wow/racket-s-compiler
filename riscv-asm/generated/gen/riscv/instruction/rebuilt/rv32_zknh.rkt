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

(define sha512sum0r
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 30 31 1) (bit-range-fixed 25 29 8) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 51))))
(define sha512sum1r
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 30 31 1) (bit-range-fixed 25 29 9) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 51))))
(define sha512sig0l
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 30 31 1) (bit-range-fixed 25 29 10) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 51))))
(define sha512sig0h
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 30 31 1) (bit-range-fixed 25 29 14) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 51))))
(define sha512sig1l
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 30 31 1) (bit-range-fixed 25 29 11) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 51))))
(define sha512sig1h
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 30 31 1) (bit-range-fixed 25 29 15) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 51))))

(provide
 sha512sum0r
 sha512sum1r
 sha512sig0l
 sha512sig0h
 sha512sig1l
 sha512sig1h)
