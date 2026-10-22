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

(define rolw
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 25 31 48) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 14) (bit-range-fixed 0 1 3))))
(define rorw
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 25 31 48) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 14) (bit-range-fixed 0 1 3))))
(define roriw
  (make-instruction
   (list raw:rd raw:rs1 raw:shamtw)
   (list (bit-range-fixed 25 31 48) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 6) (bit-range-fixed 0 1 3))))
(define rori
  (make-instruction
   (list raw:rd raw:rs1 raw:shamtd)
   (list (bit-range-fixed 26 31 24) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define packw
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 25 31 4) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 14) (bit-range-fixed 0 1 3))))
(define rev8
  (make-instruction
   (list raw:rd raw:rs1)
   (list (bit-range-fixed 20 31 1720) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 19))))

(provide
 rolw
 rorw
 roriw
 rori
 packw
 rev8)
