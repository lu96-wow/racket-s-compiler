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

(define ntl.p1
  (make-instruction
   (list)
   (list (bit-range-fixed 25 31 0) (bit-range-fixed 20 24 2) (bit-range-fixed 15 19 0) (bit-range-fixed 12 14 0) (bit-range-fixed 7 11 0) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define ntl.pall
  (make-instruction
   (list)
   (list (bit-range-fixed 25 31 0) (bit-range-fixed 20 24 3) (bit-range-fixed 15 19 0) (bit-range-fixed 12 14 0) (bit-range-fixed 7 11 0) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define ntl.s1
  (make-instruction
   (list)
   (list (bit-range-fixed 25 31 0) (bit-range-fixed 20 24 4) (bit-range-fixed 15 19 0) (bit-range-fixed 12 14 0) (bit-range-fixed 7 11 0) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define ntl.all
  (make-instruction
   (list)
   (list (bit-range-fixed 25 31 0) (bit-range-fixed 20 24 5) (bit-range-fixed 15 19 0) (bit-range-fixed 12 14 0) (bit-range-fixed 7 11 0) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))

(provide
 ntl.p1
 ntl.pall
 ntl.s1
 ntl.all)
