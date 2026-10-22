#lang racket/base

(require "../../../base.rkt"
         "../../raw/scalar.rkt"
         "../../raw/compressed.rkt"
         "../../raw/vector.rkt"
         "../../raw/mop.rkt")

(define c.ld
  (make-instruction
   (list rd_p rs1_p c_uimm8lo c_uimm8hi)
   (list (bit-range-fixed 0 1 0) (bit-range-fixed 13 15 3))))
(define c.sd
  (make-instruction
   (list rs1_p rs2_p c_uimm8hi c_uimm8lo)
   (list (bit-range-fixed 0 1 0) (bit-range-fixed 13 15 7))))
(define c.addiw
  (make-instruction
   (list rd_rs1_n0 c_imm6lo c_imm6hi)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 1))))
(define c.srli
  (make-instruction
   (list rd_rs1_p c_nzuimm6lo c_nzuimm6hi)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 4) (bit-range-fixed 10 11 0))))
(define c.srai
  (make-instruction
   (list rd_rs1_p c_nzuimm6lo c_nzuimm6hi)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 4) (bit-range-fixed 10 11 1))))
(define c.subw
  (make-instruction
   (list rd_rs1_p rs2_p)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 4) (bit-range-fixed 10 12 7) (bit-range-fixed 5 6 0))))
(define c.addw
  (make-instruction
   (list rd_rs1_p rs2_p)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 4) (bit-range-fixed 10 12 7) (bit-range-fixed 5 6 1))))
(define c.slli
  (make-instruction
   (list rd_rs1_n0 c_nzuimm6hi c_nzuimm6lo)
   (list (bit-range-fixed 0 1 2) (bit-range-fixed 13 15 0))))
(define c.ldsp
  (make-instruction
   (list rd_n0 c_uimm9sphi c_uimm9splo)
   (list (bit-range-fixed 0 1 2) (bit-range-fixed 13 15 3))))
(define c.sdsp
  (make-instruction
   (list c_rs2 c_uimm9sp_s)
   (list (bit-range-fixed 0 1 2) (bit-range-fixed 13 15 7))))

(provide
 c.ld
 c.sd
 c.addiw
 c.srli
 c.srai
 c.subw
 c.addw
 c.slli
 c.ldsp
 c.sdsp)
