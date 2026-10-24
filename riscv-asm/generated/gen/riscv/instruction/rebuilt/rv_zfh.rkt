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

(define fmadd.h
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2 raw:rs3 raw:rm)
   (list (bit-range-fixed 25 26 2) (bit-range-fixed 2 6 16) (bit-range-fixed 0 1 3))))
(define fmsub.h
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2 raw:rs3 raw:rm)
   (list (bit-range-fixed 25 26 2) (bit-range-fixed 2 6 17) (bit-range-fixed 0 1 3))))
(define fnmsub.h
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2 raw:rs3 raw:rm)
   (list (bit-range-fixed 25 26 2) (bit-range-fixed 2 6 18) (bit-range-fixed 0 1 3))))
(define fnmadd.h
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2 raw:rs3 raw:rm)
   (list (bit-range-fixed 25 26 2) (bit-range-fixed 2 6 19) (bit-range-fixed 0 1 3))))
(define fadd.h
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2 raw:rm)
   (list (bit-range-fixed 27 31 0) (bit-range-fixed 25 26 2) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fsub.h
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2 raw:rm)
   (list (bit-range-fixed 27 31 1) (bit-range-fixed 25 26 2) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fmul.h
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2 raw:rm)
   (list (bit-range-fixed 27 31 2) (bit-range-fixed 25 26 2) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fdiv.h
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2 raw:rm)
   (list (bit-range-fixed 27 31 3) (bit-range-fixed 25 26 2) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fsqrt.h
  (make-instruction
   (list raw:rd raw:rs1 raw:rm)
   (list (bit-range-fixed 20 24 0) (bit-range-fixed 27 31 11) (bit-range-fixed 25 26 2) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fsgnj.h
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 27 31 4) (bit-range-fixed 12 14 0) (bit-range-fixed 25 26 2) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fsgnjn.h
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 27 31 4) (bit-range-fixed 12 14 1) (bit-range-fixed 25 26 2) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fsgnjx.h
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 27 31 4) (bit-range-fixed 12 14 2) (bit-range-fixed 25 26 2) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fmin.h
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 27 31 5) (bit-range-fixed 12 14 0) (bit-range-fixed 25 26 2) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fmax.h
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 27 31 5) (bit-range-fixed 12 14 1) (bit-range-fixed 25 26 2) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define feq.h
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 27 31 20) (bit-range-fixed 12 14 2) (bit-range-fixed 25 26 2) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define flt.h
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 27 31 20) (bit-range-fixed 12 14 1) (bit-range-fixed 25 26 2) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fle.h
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 27 31 20) (bit-range-fixed 12 14 0) (bit-range-fixed 25 26 2) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fclass.h
  (make-instruction
   (list raw:rd raw:rs1)
   (list (bit-range-fixed 20 24 0) (bit-range-fixed 27 31 28) (bit-range-fixed 12 14 1) (bit-range-fixed 25 26 2) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fcvt.w.h
  (make-instruction
   (list raw:rd raw:rs1 raw:rm)
   (list (bit-range-fixed 20 24 0) (bit-range-fixed 27 31 24) (bit-range-fixed 25 26 2) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fcvt.wu.h
  (make-instruction
   (list raw:rd raw:rs1 raw:rm)
   (list (bit-range-fixed 20 24 1) (bit-range-fixed 27 31 24) (bit-range-fixed 25 26 2) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fcvt.h.w
  (make-instruction
   (list raw:rd raw:rs1 raw:rm)
   (list (bit-range-fixed 20 24 0) (bit-range-fixed 27 31 26) (bit-range-fixed 25 26 2) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fcvt.h.wu
  (make-instruction
   (list raw:rd raw:rs1 raw:rm)
   (list (bit-range-fixed 20 24 1) (bit-range-fixed 27 31 26) (bit-range-fixed 25 26 2) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fmv.h
  (let ([encode (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 27 31 4) (bit-range-fixed 12 14 0) (bit-range-fixed 25 26 2) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3)))])
    (lambda (rd rs1)
      (encode rd rs1 rs1))))
(define fabs.h
  (let ([encode (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 27 31 4) (bit-range-fixed 12 14 2) (bit-range-fixed 25 26 2) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3)))])
    (lambda (rd rs1)
      (encode rd rs1 rs1))))
(define fneg.h
  (let ([encode (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 27 31 4) (bit-range-fixed 12 14 1) (bit-range-fixed 25 26 2) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3)))])
    (lambda (rd rs1)
      (encode rd rs1 rs1))))

(provide
 fmadd.h
 fmsub.h
 fnmsub.h
 fnmadd.h
 fadd.h
 fsub.h
 fmul.h
 fdiv.h
 fsqrt.h
 fsgnj.h
 fsgnjn.h
 fsgnjx.h
 fmin.h
 fmax.h
 feq.h
 flt.h
 fle.h
 fclass.h
 fcvt.w.h
 fcvt.wu.h
 fcvt.h.w
 fcvt.h.wu
 fmv.h
 fabs.h
 fneg.h)
