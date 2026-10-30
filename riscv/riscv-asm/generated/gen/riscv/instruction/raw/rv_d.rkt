#lang racket/base

(require "../../../../lib/base.rkt"
         "../../../../lib/riscv/raw/scalar.rkt"
         "../../../../lib/riscv/raw/compressed.rkt"
         "../../../../lib/riscv/raw/vector.rkt"
         "../../../../lib/riscv/raw/mop.rkt")

(define fld
  (make-instruction
   (list rd rs1 imm12)
   (list (bit-range-fixed 12 14 3) (bit-range-fixed 2 6 1) (bit-range-fixed 0 1 3))))
(define fsd
  (make-instruction
   (list imm12hi rs1 rs2 imm12lo)
   (list (bit-range-fixed 12 14 3) (bit-range-fixed 2 6 9) (bit-range-fixed 0 1 3))))
(define fmadd.d
  (make-instruction
   (list rd rs1 rs2 rs3 rm)
   (list (bit-range-fixed 25 26 1) (bit-range-fixed 2 6 16) (bit-range-fixed 0 1 3))))
(define fmsub.d
  (make-instruction
   (list rd rs1 rs2 rs3 rm)
   (list (bit-range-fixed 25 26 1) (bit-range-fixed 2 6 17) (bit-range-fixed 0 1 3))))
(define fnmsub.d
  (make-instruction
   (list rd rs1 rs2 rs3 rm)
   (list (bit-range-fixed 25 26 1) (bit-range-fixed 2 6 18) (bit-range-fixed 0 1 3))))
(define fnmadd.d
  (make-instruction
   (list rd rs1 rs2 rs3 rm)
   (list (bit-range-fixed 25 26 1) (bit-range-fixed 2 6 19) (bit-range-fixed 0 1 3))))
(define fadd.d
  (make-instruction
   (list rd rs1 rs2 rm)
   (list (bit-range-fixed 27 31 0) (bit-range-fixed 25 26 1) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fsub.d
  (make-instruction
   (list rd rs1 rs2 rm)
   (list (bit-range-fixed 27 31 1) (bit-range-fixed 25 26 1) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fmul.d
  (make-instruction
   (list rd rs1 rs2 rm)
   (list (bit-range-fixed 27 31 2) (bit-range-fixed 25 26 1) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fdiv.d
  (make-instruction
   (list rd rs1 rs2 rm)
   (list (bit-range-fixed 27 31 3) (bit-range-fixed 25 26 1) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fsqrt.d
  (make-instruction
   (list rd rs1 rm)
   (list (bit-range-fixed 20 24 0) (bit-range-fixed 27 31 11) (bit-range-fixed 25 26 1) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fsgnj.d
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 27 31 4) (bit-range-fixed 12 14 0) (bit-range-fixed 25 26 1) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fsgnjn.d
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 27 31 4) (bit-range-fixed 12 14 1) (bit-range-fixed 25 26 1) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fsgnjx.d
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 27 31 4) (bit-range-fixed 12 14 2) (bit-range-fixed 25 26 1) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fmin.d
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 27 31 5) (bit-range-fixed 12 14 0) (bit-range-fixed 25 26 1) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fmax.d
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 27 31 5) (bit-range-fixed 12 14 1) (bit-range-fixed 25 26 1) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fcvt.s.d
  (make-instruction
   (list rd rs1 rm)
   (list (bit-range-fixed 20 24 1) (bit-range-fixed 27 31 8) (bit-range-fixed 25 26 0) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fcvt.d.s
  (make-instruction
   (list rd rs1 rm)
   (list (bit-range-fixed 20 24 0) (bit-range-fixed 27 31 8) (bit-range-fixed 25 26 1) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define feq.d
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 27 31 20) (bit-range-fixed 12 14 2) (bit-range-fixed 25 26 1) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define flt.d
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 27 31 20) (bit-range-fixed 12 14 1) (bit-range-fixed 25 26 1) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fle.d
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 27 31 20) (bit-range-fixed 12 14 0) (bit-range-fixed 25 26 1) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fclass.d
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 20 24 0) (bit-range-fixed 27 31 28) (bit-range-fixed 12 14 1) (bit-range-fixed 25 26 1) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fcvt.w.d
  (make-instruction
   (list rd rs1 rm)
   (list (bit-range-fixed 20 24 0) (bit-range-fixed 27 31 24) (bit-range-fixed 25 26 1) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fcvt.wu.d
  (make-instruction
   (list rd rs1 rm)
   (list (bit-range-fixed 20 24 1) (bit-range-fixed 27 31 24) (bit-range-fixed 25 26 1) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fcvt.d.w
  (make-instruction
   (list rd rs1 rm)
   (list (bit-range-fixed 20 24 0) (bit-range-fixed 27 31 26) (bit-range-fixed 25 26 1) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fcvt.d.wu
  (make-instruction
   (list rd rs1 rm)
   (list (bit-range-fixed 20 24 1) (bit-range-fixed 27 31 26) (bit-range-fixed 25 26 1) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fmv.d
  (let ([encode (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 27 31 4) (bit-range-fixed 12 14 0) (bit-range-fixed 25 26 1) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3)))])
    (lambda (rd rs1)
      (encode rd rs1 rs1))))
(define fabs.d
  (let ([encode (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 27 31 4) (bit-range-fixed 12 14 2) (bit-range-fixed 25 26 1) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3)))])
    (lambda (rd rs1)
      (encode rd rs1 rs1))))
(define fneg.d
  (let ([encode (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 27 31 4) (bit-range-fixed 12 14 1) (bit-range-fixed 25 26 1) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3)))])
    (lambda (rd rs1)
      (encode rd rs1 rs1))))

(provide
 fld
 fsd
 fmadd.d
 fmsub.d
 fnmsub.d
 fnmadd.d
 fadd.d
 fsub.d
 fmul.d
 fdiv.d
 fsqrt.d
 fsgnj.d
 fsgnjn.d
 fsgnjx.d
 fmin.d
 fmax.d
 fcvt.s.d
 fcvt.d.s
 feq.d
 flt.d
 fle.d
 fclass.d
 fcvt.w.d
 fcvt.wu.d
 fcvt.d.w
 fcvt.d.wu
 fmv.d
 fabs.d
 fneg.d)
