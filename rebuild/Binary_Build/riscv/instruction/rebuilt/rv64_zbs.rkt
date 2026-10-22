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

(define bclri
  (make-instruction
   (list raw:rd raw:rs1 raw:shamtd)
   (list (bit-range-fixed 26 31 18) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define bexti
  (make-instruction
   (list raw:rd raw:rs1 raw:shamtd)
   (list (bit-range-fixed 26 31 18) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define binvi
  (make-instruction
   (list raw:rd raw:rs1 raw:shamtd)
   (list (bit-range-fixed 26 31 26) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define bseti
  (make-instruction
   (list raw:rd raw:rs1 raw:shamtd)
   (list (bit-range-fixed 26 31 10) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))

(provide
 bclri
 bexti
 binvi
 bseti)
