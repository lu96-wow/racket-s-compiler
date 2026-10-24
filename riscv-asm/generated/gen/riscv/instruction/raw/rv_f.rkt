#lang racket/base

(require "../../../../lib/base.rkt"
         "../../../../lib/riscv/raw/scalar.rkt"
         "../../../../lib/riscv/raw/compressed.rkt"
         "../../../../lib/riscv/raw/vector.rkt"
         "../../../../lib/riscv/raw/mop.rkt")

(define flw
  (make-instruction
   (list rd rs1 imm12)
   (list (bit-range-fixed 12 14 2) (bit-range-fixed 2 6 1) (bit-range-fixed 0 1 3))))
(define fsw
  (make-instruction
   (list imm12hi rs1 rs2 imm12lo)
   (list (bit-range-fixed 12 14 2) (bit-range-fixed 2 6 9) (bit-range-fixed 0 1 3))))
(define fmadd.s
  (make-instruction
   (list rd rs1 rs2 rs3 rm)
   (list (bit-range-fixed 25 26 0) (bit-range-fixed 2 6 16) (bit-range-fixed 0 1 3))))
(define fmsub.s
  (make-instruction
   (list rd rs1 rs2 rs3 rm)
   (list (bit-range-fixed 25 26 0) (bit-range-fixed 2 6 17) (bit-range-fixed 0 1 3))))
(define fnmsub.s
  (make-instruction
   (list rd rs1 rs2 rs3 rm)
   (list (bit-range-fixed 25 26 0) (bit-range-fixed 2 6 18) (bit-range-fixed 0 1 3))))
(define fnmadd.s
  (make-instruction
   (list rd rs1 rs2 rs3 rm)
   (list (bit-range-fixed 25 26 0) (bit-range-fixed 2 6 19) (bit-range-fixed 0 1 3))))
(define fadd.s
  (make-instruction
   (list rd rs1 rs2 rm)
   (list (bit-range-fixed 27 31 0) (bit-range-fixed 25 26 0) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fsub.s
  (make-instruction
   (list rd rs1 rs2 rm)
   (list (bit-range-fixed 27 31 1) (bit-range-fixed 25 26 0) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fmul.s
  (make-instruction
   (list rd rs1 rs2 rm)
   (list (bit-range-fixed 27 31 2) (bit-range-fixed 25 26 0) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fdiv.s
  (make-instruction
   (list rd rs1 rs2 rm)
   (list (bit-range-fixed 27 31 3) (bit-range-fixed 25 26 0) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fsqrt.s
  (make-instruction
   (list rd rs1 rm)
   (list (bit-range-fixed 20 24 0) (bit-range-fixed 27 31 11) (bit-range-fixed 25 26 0) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fsgnj.s
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 27 31 4) (bit-range-fixed 12 14 0) (bit-range-fixed 25 26 0) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fsgnjn.s
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 27 31 4) (bit-range-fixed 12 14 1) (bit-range-fixed 25 26 0) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fsgnjx.s
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 27 31 4) (bit-range-fixed 12 14 2) (bit-range-fixed 25 26 0) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fmin.s
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 27 31 5) (bit-range-fixed 12 14 0) (bit-range-fixed 25 26 0) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fmax.s
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 27 31 5) (bit-range-fixed 12 14 1) (bit-range-fixed 25 26 0) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fcvt.w.s
  (make-instruction
   (list rd rs1 rm)
   (list (bit-range-fixed 20 24 0) (bit-range-fixed 27 31 24) (bit-range-fixed 25 26 0) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fcvt.wu.s
  (make-instruction
   (list rd rs1 rm)
   (list (bit-range-fixed 20 24 1) (bit-range-fixed 27 31 24) (bit-range-fixed 25 26 0) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fmv.x.w
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 20 24 0) (bit-range-fixed 27 31 28) (bit-range-fixed 12 14 0) (bit-range-fixed 25 26 0) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define feq.s
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 27 31 20) (bit-range-fixed 12 14 2) (bit-range-fixed 25 26 0) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define flt.s
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 27 31 20) (bit-range-fixed 12 14 1) (bit-range-fixed 25 26 0) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fle.s
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 27 31 20) (bit-range-fixed 12 14 0) (bit-range-fixed 25 26 0) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fclass.s
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 20 24 0) (bit-range-fixed 27 31 28) (bit-range-fixed 12 14 1) (bit-range-fixed 25 26 0) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fcvt.s.w
  (make-instruction
   (list rd rs1 rm)
   (list (bit-range-fixed 20 24 0) (bit-range-fixed 27 31 26) (bit-range-fixed 25 26 0) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fcvt.s.wu
  (make-instruction
   (list rd rs1 rm)
   (list (bit-range-fixed 20 24 1) (bit-range-fixed 27 31 26) (bit-range-fixed 25 26 0) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fmv.w.x
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 20 24 0) (bit-range-fixed 27 31 30) (bit-range-fixed 12 14 0) (bit-range-fixed 25 26 0) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fmv.x.s
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 20 24 0) (bit-range-fixed 27 31 28) (bit-range-fixed 12 14 0) (bit-range-fixed 25 26 0) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fmv.s.x
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 20 24 0) (bit-range-fixed 27 31 30) (bit-range-fixed 12 14 0) (bit-range-fixed 25 26 0) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fmv.s
  (let ([encode (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 27 31 4) (bit-range-fixed 12 14 0) (bit-range-fixed 25 26 0) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3)))])
    (lambda (rd rs1)
      (encode rd rs1 rs1))))
(define fabs.s
  (let ([encode (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 27 31 4) (bit-range-fixed 12 14 2) (bit-range-fixed 25 26 0) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3)))])
    (lambda (rd rs1)
      (encode rd rs1 rs1))))
(define fneg.s
  (let ([encode (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 27 31 4) (bit-range-fixed 12 14 1) (bit-range-fixed 25 26 0) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3)))])
    (lambda (rd rs1)
      (encode rd rs1 rs1))))
(define frflags
  (make-instruction
   (list rd)
   (list (bit-range-fixed 15 19 0) (bit-range-fixed 20 31 1) (bit-range-fixed 12 14 2) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define fsflags
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 20 31 1) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define fsflagsi
  (make-instruction
   (list rd zimm5)
   (list (bit-range-fixed 20 31 1) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define frrm
  (make-instruction
   (list rd)
   (list (bit-range-fixed 15 19 0) (bit-range-fixed 20 31 2) (bit-range-fixed 12 14 2) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define fsrm
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 20 31 2) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define fsrmi
  (make-instruction
   (list rd zimm5)
   (list (bit-range-fixed 20 31 2) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define fscsr
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 20 31 3) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define frcsr
  (make-instruction
   (list rd)
   (list (bit-range-fixed 15 19 0) (bit-range-fixed 20 31 3) (bit-range-fixed 12 14 2) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))

(provide
 flw
 fsw
 fmadd.s
 fmsub.s
 fnmsub.s
 fnmadd.s
 fadd.s
 fsub.s
 fmul.s
 fdiv.s
 fsqrt.s
 fsgnj.s
 fsgnjn.s
 fsgnjx.s
 fmin.s
 fmax.s
 fcvt.w.s
 fcvt.wu.s
 fmv.x.w
 feq.s
 flt.s
 fle.s
 fclass.s
 fcvt.s.w
 fcvt.s.wu
 fmv.w.x
 fmv.x.s
 fmv.s.x
 fmv.s
 fabs.s
 fneg.s
 frflags
 fsflags
 fsflagsi
 frrm
 fsrm
 fsrmi
 fscsr
 frcsr)
