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

(define fcvt.l.d
  (make-instruction
   (list raw:rd raw:rs1 raw:rm)
   (list (bit-range-fixed 20 24 2) (bit-range-fixed 27 31 24) (bit-range-fixed 25 26 1) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fcvt.lu.d
  (make-instruction
   (list raw:rd raw:rs1 raw:rm)
   (list (bit-range-fixed 20 24 3) (bit-range-fixed 27 31 24) (bit-range-fixed 25 26 1) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fmv.x.d
  (make-instruction
   (list raw:rd raw:rs1)
   (list (bit-range-fixed 20 24 0) (bit-range-fixed 27 31 28) (bit-range-fixed 12 14 0) (bit-range-fixed 25 26 1) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fcvt.d.l
  (make-instruction
   (list raw:rd raw:rs1 raw:rm)
   (list (bit-range-fixed 20 24 2) (bit-range-fixed 27 31 26) (bit-range-fixed 25 26 1) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fcvt.d.lu
  (make-instruction
   (list raw:rd raw:rs1 raw:rm)
   (list (bit-range-fixed 20 24 3) (bit-range-fixed 27 31 26) (bit-range-fixed 25 26 1) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fmv.d.x
  (make-instruction
   (list raw:rd raw:rs1)
   (list (bit-range-fixed 20 24 0) (bit-range-fixed 27 31 30) (bit-range-fixed 12 14 0) (bit-range-fixed 25 26 1) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))

(provide
 fcvt.l.d
 fcvt.lu.d
 fmv.x.d
 fcvt.d.l
 fcvt.d.lu
 fmv.d.x)
