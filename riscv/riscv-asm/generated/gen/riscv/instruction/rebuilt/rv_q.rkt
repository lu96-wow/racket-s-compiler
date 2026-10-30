#lang racket/base

(require "../../../../lib/base.rkt"
         (prefix-in raw: "../../../../lib/riscv/raw/scalar.rkt")
         (prefix-in raw: "../../../../lib/riscv/raw/compressed.rkt")
         (prefix-in raw: "../../../../lib/riscv/raw/vector.rkt")
         (prefix-in raw: "../../../../lib/riscv/raw/mop.rkt")
         (prefix-in rebuilt: "../../field/rebuilt/scalar.rkt")
         (prefix-in rebuilt: "../../field/rebuilt/compressed.rkt")
         (prefix-in rebuilt: "../../field/rebuilt/vector.rkt")
         (prefix-in rebuilt: "../../field/rebuilt/mop.rkt"))

(define flq
  (make-instruction
   (list raw:rd raw:rs1 raw:imm12)
   (list (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 1) (bit-range-fixed 0 1 3))))
(define fsq
  (let ([encode (make-instruction
   (list rebuilt:simm12 raw:rs1 raw:rs2 rebuilt:simm12)
   (list (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 9) (bit-range-fixed 0 1 3)))])
    (lambda (simm12 rs1 rs2)
      (encode simm12 rs1 rs2 simm12))))
(define fmadd.q
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2 raw:rs3 raw:rm)
   (list (bit-range-fixed 25 26 3) (bit-range-fixed 2 6 16) (bit-range-fixed 0 1 3))))
(define fmsub.q
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2 raw:rs3 raw:rm)
   (list (bit-range-fixed 25 26 3) (bit-range-fixed 2 6 17) (bit-range-fixed 0 1 3))))
(define fnmsub.q
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2 raw:rs3 raw:rm)
   (list (bit-range-fixed 25 26 3) (bit-range-fixed 2 6 18) (bit-range-fixed 0 1 3))))
(define fnmadd.q
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2 raw:rs3 raw:rm)
   (list (bit-range-fixed 25 26 3) (bit-range-fixed 2 6 19) (bit-range-fixed 0 1 3))))
(define fadd.q
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2 raw:rm)
   (list (bit-range-fixed 27 31 0) (bit-range-fixed 25 26 3) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fsub.q
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2 raw:rm)
   (list (bit-range-fixed 27 31 1) (bit-range-fixed 25 26 3) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fmul.q
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2 raw:rm)
   (list (bit-range-fixed 27 31 2) (bit-range-fixed 25 26 3) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fdiv.q
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2 raw:rm)
   (list (bit-range-fixed 27 31 3) (bit-range-fixed 25 26 3) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fsqrt.q
  (make-instruction
   (list raw:rd raw:rs1 raw:rm)
   (list (bit-range-fixed 20 24 0) (bit-range-fixed 27 31 11) (bit-range-fixed 25 26 3) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fsgnj.q
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 27 31 4) (bit-range-fixed 12 14 0) (bit-range-fixed 25 26 3) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fsgnjn.q
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 27 31 4) (bit-range-fixed 12 14 1) (bit-range-fixed 25 26 3) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fsgnjx.q
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 27 31 4) (bit-range-fixed 12 14 2) (bit-range-fixed 25 26 3) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fmin.q
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 27 31 5) (bit-range-fixed 12 14 0) (bit-range-fixed 25 26 3) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fmax.q
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 27 31 5) (bit-range-fixed 12 14 1) (bit-range-fixed 25 26 3) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fcvt.s.q
  (make-instruction
   (list raw:rd raw:rs1 raw:rm)
   (list (bit-range-fixed 20 24 3) (bit-range-fixed 27 31 8) (bit-range-fixed 25 26 0) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fcvt.q.s
  (make-instruction
   (list raw:rd raw:rs1 raw:rm)
   (list (bit-range-fixed 20 24 0) (bit-range-fixed 27 31 8) (bit-range-fixed 25 26 3) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fcvt.d.q
  (make-instruction
   (list raw:rd raw:rs1 raw:rm)
   (list (bit-range-fixed 20 24 3) (bit-range-fixed 27 31 8) (bit-range-fixed 25 26 1) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fcvt.q.d
  (make-instruction
   (list raw:rd raw:rs1 raw:rm)
   (list (bit-range-fixed 20 24 1) (bit-range-fixed 27 31 8) (bit-range-fixed 25 26 3) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define feq.q
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 27 31 20) (bit-range-fixed 12 14 2) (bit-range-fixed 25 26 3) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define flt.q
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 27 31 20) (bit-range-fixed 12 14 1) (bit-range-fixed 25 26 3) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fle.q
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 27 31 20) (bit-range-fixed 12 14 0) (bit-range-fixed 25 26 3) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fclass.q
  (make-instruction
   (list raw:rd raw:rs1)
   (list (bit-range-fixed 20 24 0) (bit-range-fixed 27 31 28) (bit-range-fixed 12 14 1) (bit-range-fixed 25 26 3) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fcvt.w.q
  (make-instruction
   (list raw:rd raw:rs1 raw:rm)
   (list (bit-range-fixed 20 24 0) (bit-range-fixed 27 31 24) (bit-range-fixed 25 26 3) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fcvt.wu.q
  (make-instruction
   (list raw:rd raw:rs1 raw:rm)
   (list (bit-range-fixed 20 24 1) (bit-range-fixed 27 31 24) (bit-range-fixed 25 26 3) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fcvt.q.w
  (make-instruction
   (list raw:rd raw:rs1 raw:rm)
   (list (bit-range-fixed 20 24 0) (bit-range-fixed 27 31 26) (bit-range-fixed 25 26 3) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fcvt.q.wu
  (make-instruction
   (list raw:rd raw:rs1 raw:rm)
   (list (bit-range-fixed 20 24 1) (bit-range-fixed 27 31 26) (bit-range-fixed 25 26 3) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fmv.q
  (let ([encode (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 27 31 4) (bit-range-fixed 12 14 0) (bit-range-fixed 25 26 3) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3)))])
    (lambda (rd rs1)
      (encode rd rs1 rs1))))
(define fabs.q
  (let ([encode (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 27 31 4) (bit-range-fixed 12 14 2) (bit-range-fixed 25 26 3) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3)))])
    (lambda (rd rs1)
      (encode rd rs1 rs1))))
(define fneg.q
  (let ([encode (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 27 31 4) (bit-range-fixed 12 14 1) (bit-range-fixed 25 26 3) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3)))])
    (lambda (rd rs1)
      (encode rd rs1 rs1))))

(provide
 flq
 fsq
 fmadd.q
 fmsub.q
 fnmsub.q
 fnmadd.q
 fadd.q
 fsub.q
 fmul.q
 fdiv.q
 fsqrt.q
 fsgnj.q
 fsgnjn.q
 fsgnjx.q
 fmin.q
 fmax.q
 fcvt.s.q
 fcvt.q.s
 fcvt.d.q
 fcvt.q.d
 feq.q
 flt.q
 fle.q
 fclass.q
 fcvt.w.q
 fcvt.wu.q
 fcvt.q.w
 fcvt.q.wu
 fmv.q
 fabs.q
 fneg.q)
