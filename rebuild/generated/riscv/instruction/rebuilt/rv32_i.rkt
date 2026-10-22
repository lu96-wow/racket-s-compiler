#lang racket/base

(require "../../../base.rkt"
         (prefix-in raw: "../../raw/scalar.rkt")
         (prefix-in raw: "../../raw/compressed.rkt")
         (prefix-in raw: "../../raw/vector.rkt")
         (prefix-in raw: "../../raw/mop.rkt")
         (prefix-in rebuilt: "../../rebuilt/scalar.rkt")
         (prefix-in rebuilt: "../../rebuilt/compressed.rkt")
         (prefix-in rebuilt: "../../rebuilt/vector.rkt")
         (prefix-in rebuilt: "../../rebuilt/mop.rkt"))

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
