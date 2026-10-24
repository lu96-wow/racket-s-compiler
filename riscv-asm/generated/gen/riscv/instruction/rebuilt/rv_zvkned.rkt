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

(define vaesdf.vv
  (make-instruction
   (list raw:vs2 raw:vd)
   (list (bit-range-fixed 26 31 40) (bit-range-fixed 25 25 1) (bit-range-fixed 15 19 1) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 119))))
(define vaesdf.vs
  (make-instruction
   (list raw:vs2 raw:vd)
   (list (bit-range-fixed 26 31 41) (bit-range-fixed 25 25 1) (bit-range-fixed 15 19 1) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 119))))
(define vaesdm.vv
  (make-instruction
   (list raw:vs2 raw:vd)
   (list (bit-range-fixed 26 31 40) (bit-range-fixed 25 25 1) (bit-range-fixed 15 19 0) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 119))))
(define vaesdm.vs
  (make-instruction
   (list raw:vs2 raw:vd)
   (list (bit-range-fixed 26 31 41) (bit-range-fixed 25 25 1) (bit-range-fixed 15 19 0) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 119))))
(define vaesef.vv
  (make-instruction
   (list raw:vs2 raw:vd)
   (list (bit-range-fixed 26 31 40) (bit-range-fixed 25 25 1) (bit-range-fixed 15 19 3) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 119))))
(define vaesef.vs
  (make-instruction
   (list raw:vs2 raw:vd)
   (list (bit-range-fixed 26 31 41) (bit-range-fixed 25 25 1) (bit-range-fixed 15 19 3) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 119))))
(define vaesem.vv
  (make-instruction
   (list raw:vs2 raw:vd)
   (list (bit-range-fixed 26 31 40) (bit-range-fixed 25 25 1) (bit-range-fixed 15 19 2) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 119))))
(define vaesem.vs
  (make-instruction
   (list raw:vs2 raw:vd)
   (list (bit-range-fixed 26 31 41) (bit-range-fixed 25 25 1) (bit-range-fixed 15 19 2) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 119))))
(define vaesz.vs
  (make-instruction
   (list raw:vs2 raw:vd)
   (list (bit-range-fixed 26 31 41) (bit-range-fixed 25 25 1) (bit-range-fixed 15 19 7) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 119))))
(define vaeskf1.vi
  (make-instruction
   (list raw:vs2 raw:zimm5 raw:vd)
   (list (bit-range-fixed 26 31 34) (bit-range-fixed 25 25 1) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 119))))
(define vaeskf2.vi
  (make-instruction
   (list raw:vs2 raw:zimm5 raw:vd)
   (list (bit-range-fixed 26 31 42) (bit-range-fixed 25 25 1) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 119))))

(provide
 vaesdf.vv
 vaesdf.vs
 vaesdm.vv
 vaesdm.vs
 vaesef.vv
 vaesef.vs
 vaesem.vv
 vaesem.vs
 vaesz.vs
 vaeskf1.vi
 vaeskf2.vi)
