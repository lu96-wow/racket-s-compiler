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

(define c.lbu
  (make-instruction
   (list raw:rd_p raw:rs1_p raw:c_uimm2)
   (list (bit-range-fixed 0 1 0) (bit-range-fixed 13 15 4) (bit-range-fixed 10 12 0))))
(define c.lhu
  (make-instruction
   (list raw:rd_p raw:rs1_p raw:c_uimm1)
   (list (bit-range-fixed 0 1 0) (bit-range-fixed 13 15 4) (bit-range-fixed 10 12 1) (bit-range-fixed 6 6 0))))
(define c.lh
  (make-instruction
   (list raw:rd_p raw:rs1_p raw:c_uimm1)
   (list (bit-range-fixed 0 1 0) (bit-range-fixed 13 15 4) (bit-range-fixed 10 12 1) (bit-range-fixed 6 6 1))))
(define c.sb
  (make-instruction
   (list raw:rs2_p raw:rs1_p raw:c_uimm2)
   (list (bit-range-fixed 0 1 0) (bit-range-fixed 13 15 4) (bit-range-fixed 10 12 2))))
(define c.sh
  (make-instruction
   (list raw:rs2_p raw:rs1_p raw:c_uimm1)
   (list (bit-range-fixed 0 1 0) (bit-range-fixed 13 15 4) (bit-range-fixed 10 12 3) (bit-range-fixed 6 6 0))))
(define c.zext.b
  (make-instruction
   (list raw:rd_rs1_p)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 4) (bit-range-fixed 10 12 7) (bit-range-fixed 5 6 3) (bit-range-fixed 2 4 0))))
(define c.sext.b
  (make-instruction
   (list raw:rd_rs1_p)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 4) (bit-range-fixed 10 12 7) (bit-range-fixed 5 6 3) (bit-range-fixed 2 4 1))))
(define c.zext.h
  (make-instruction
   (list raw:rd_rs1_p)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 4) (bit-range-fixed 10 12 7) (bit-range-fixed 5 6 3) (bit-range-fixed 2 4 2))))
(define c.sext.h
  (make-instruction
   (list raw:rd_rs1_p)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 4) (bit-range-fixed 10 12 7) (bit-range-fixed 5 6 3) (bit-range-fixed 2 4 3))))
(define c.not
  (make-instruction
   (list raw:rd_rs1_p)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 4) (bit-range-fixed 10 12 7) (bit-range-fixed 5 6 3) (bit-range-fixed 2 4 5))))
(define c.mul
  (make-instruction
   (list raw:rd_rs1_p raw:rs2_p)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 4) (bit-range-fixed 10 12 7) (bit-range-fixed 5 6 2))))

(provide
 c.lbu
 c.lhu
 c.lh
 c.sb
 c.sh
 c.zext.b
 c.sext.b
 c.zext.h
 c.sext.h
 c.not
 c.mul)
