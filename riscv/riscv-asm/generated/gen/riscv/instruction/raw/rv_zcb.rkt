#lang racket/base

(require "../../../../lib/base.rkt"
         "../../../../lib/riscv/raw/scalar.rkt"
         "../../../../lib/riscv/raw/compressed.rkt"
         "../../../../lib/riscv/raw/vector.rkt"
         "../../../../lib/riscv/raw/mop.rkt")

(define c.lbu
  (make-instruction
   (list rd_p rs1_p c_uimm2)
   (list (bit-range-fixed 0 1 0) (bit-range-fixed 13 15 4) (bit-range-fixed 10 12 0))))
(define c.lhu
  (make-instruction
   (list rd_p rs1_p c_uimm1)
   (list (bit-range-fixed 0 1 0) (bit-range-fixed 13 15 4) (bit-range-fixed 10 12 1) (bit-range-fixed 6 6 0))))
(define c.lh
  (make-instruction
   (list rd_p rs1_p c_uimm1)
   (list (bit-range-fixed 0 1 0) (bit-range-fixed 13 15 4) (bit-range-fixed 10 12 1) (bit-range-fixed 6 6 1))))
(define c.sb
  (make-instruction
   (list rs2_p rs1_p c_uimm2)
   (list (bit-range-fixed 0 1 0) (bit-range-fixed 13 15 4) (bit-range-fixed 10 12 2))))
(define c.sh
  (make-instruction
   (list rs2_p rs1_p c_uimm1)
   (list (bit-range-fixed 0 1 0) (bit-range-fixed 13 15 4) (bit-range-fixed 10 12 3) (bit-range-fixed 6 6 0))))
(define c.zext.b
  (make-instruction
   (list rd_rs1_p)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 4) (bit-range-fixed 10 12 7) (bit-range-fixed 5 6 3) (bit-range-fixed 2 4 0))))
(define c.sext.b
  (make-instruction
   (list rd_rs1_p)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 4) (bit-range-fixed 10 12 7) (bit-range-fixed 5 6 3) (bit-range-fixed 2 4 1))))
(define c.zext.h
  (make-instruction
   (list rd_rs1_p)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 4) (bit-range-fixed 10 12 7) (bit-range-fixed 5 6 3) (bit-range-fixed 2 4 2))))
(define c.sext.h
  (make-instruction
   (list rd_rs1_p)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 4) (bit-range-fixed 10 12 7) (bit-range-fixed 5 6 3) (bit-range-fixed 2 4 3))))
(define c.not
  (make-instruction
   (list rd_rs1_p)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 4) (bit-range-fixed 10 12 7) (bit-range-fixed 5 6 3) (bit-range-fixed 2 4 5))))
(define c.mul
  (make-instruction
   (list rd_rs1_p rs2_p)
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
