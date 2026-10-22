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

(define c.ntl.p1
  (make-instruction
   (list)
   (list (bit-range-fixed 0 1 2) (bit-range-fixed 2 6 2) (bit-range-fixed 7 11 0) (bit-range-fixed 13 15 4) (bit-range-fixed 12 12 1))))
(define c.ntl.pall
  (make-instruction
   (list)
   (list (bit-range-fixed 0 1 2) (bit-range-fixed 2 6 3) (bit-range-fixed 7 11 0) (bit-range-fixed 13 15 4) (bit-range-fixed 12 12 1))))
(define c.ntl.s1
  (make-instruction
   (list)
   (list (bit-range-fixed 0 1 2) (bit-range-fixed 2 6 4) (bit-range-fixed 7 11 0) (bit-range-fixed 13 15 4) (bit-range-fixed 12 12 1))))
(define c.ntl.all
  (make-instruction
   (list)
   (list (bit-range-fixed 0 1 2) (bit-range-fixed 2 6 5) (bit-range-fixed 7 11 0) (bit-range-fixed 13 15 4) (bit-range-fixed 12 12 1))))

(provide
 c.ntl.p1
 c.ntl.pall
 c.ntl.s1
 c.ntl.all)
