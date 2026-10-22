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

(define c.mop.N
  (make-instruction
   (list raw:c_mop_t)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 2 6 0) (bit-range-fixed 11 11 0) (bit-range-fixed 7 7 1) (bit-range-fixed 12 12 0) (bit-range-fixed 13 15 3))))
(define c.mop.1
  (make-instruction
   (list)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 2 6 0) (bit-range-fixed 7 11 1) (bit-range-fixed 12 12 0) (bit-range-fixed 13 15 3))))
(define c.mop.3
  (make-instruction
   (list)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 2 6 0) (bit-range-fixed 7 11 3) (bit-range-fixed 12 12 0) (bit-range-fixed 13 15 3))))
(define c.mop.5
  (make-instruction
   (list)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 2 6 0) (bit-range-fixed 7 11 5) (bit-range-fixed 12 12 0) (bit-range-fixed 13 15 3))))
(define c.mop.7
  (make-instruction
   (list)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 2 6 0) (bit-range-fixed 7 11 7) (bit-range-fixed 12 12 0) (bit-range-fixed 13 15 3))))
(define c.mop.9
  (make-instruction
   (list)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 2 6 0) (bit-range-fixed 7 11 9) (bit-range-fixed 12 12 0) (bit-range-fixed 13 15 3))))
(define c.mop.11
  (make-instruction
   (list)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 2 6 0) (bit-range-fixed 7 11 11) (bit-range-fixed 12 12 0) (bit-range-fixed 13 15 3))))
(define c.mop.13
  (make-instruction
   (list)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 2 6 0) (bit-range-fixed 7 11 13) (bit-range-fixed 12 12 0) (bit-range-fixed 13 15 3))))
(define c.mop.15
  (make-instruction
   (list)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 2 6 0) (bit-range-fixed 7 11 15) (bit-range-fixed 12 12 0) (bit-range-fixed 13 15 3))))

(provide
 c.mop.N
 c.mop.1
 c.mop.3
 c.mop.5
 c.mop.7
 c.mop.9
 c.mop.11
 c.mop.13
 c.mop.15)
