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

(define mulw
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 25 31 1) (bit-range-fixed 12 14 0) (bit-range-fixed 2 6 14) (bit-range-fixed 0 1 3))))
(define divw
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 25 31 1) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 14) (bit-range-fixed 0 1 3))))
(define divuw
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 25 31 1) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 14) (bit-range-fixed 0 1 3))))
(define remw
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 25 31 1) (bit-range-fixed 12 14 6) (bit-range-fixed 2 6 14) (bit-range-fixed 0 1 3))))
(define remuw
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 25 31 1) (bit-range-fixed 12 14 7) (bit-range-fixed 2 6 14) (bit-range-fixed 0 1 3))))

(provide
 mulw
 divw
 divuw
 remw
 remuw)
