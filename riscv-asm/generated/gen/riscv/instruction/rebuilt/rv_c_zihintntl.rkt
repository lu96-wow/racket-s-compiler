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
