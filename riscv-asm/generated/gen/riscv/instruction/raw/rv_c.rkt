#lang racket/base

(require "../../../../lib/base.rkt"
         "../../../../lib/riscv/raw/scalar.rkt"
         "../../../../lib/riscv/raw/compressed.rkt"
         "../../../../lib/riscv/raw/vector.rkt"
         "../../../../lib/riscv/raw/mop.rkt")

(define c.addi4spn
  (make-instruction
   (list rd_p c_nzuimm10)
   (list (bit-range-fixed 0 1 0) (bit-range-fixed 13 15 0))))
(define c.lw
  (make-instruction
   (list rd_p rs1_p c_uimm7lo c_uimm7hi)
   (list (bit-range-fixed 0 1 0) (bit-range-fixed 13 15 2))))
(define c.sw
  (make-instruction
   (list rs1_p rs2_p c_uimm7lo c_uimm7hi)
   (list (bit-range-fixed 0 1 0) (bit-range-fixed 13 15 6))))
(define c.nop
  (make-instruction
   (list c_nzimm6hi c_nzimm6lo)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 0) (bit-range-fixed 7 11 0))))
(define c.addi
  (make-instruction
   (list rd_rs1_n0 c_nzimm6lo c_nzimm6hi)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 0))))
(define c.li
  (make-instruction
   (list rd_n0 c_imm6lo c_imm6hi)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 2))))
(define c.addi16sp
  (make-instruction
   (list c_nzimm10hi c_nzimm10lo)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 3) (bit-range-fixed 7 11 2))))
(define c.lui
  (make-instruction
   (list rd_n2 c_nzimm18hi c_nzimm18lo)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 3))))
(define c.andi
  (make-instruction
   (list rd_rs1_p c_imm6hi c_imm6lo)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 4) (bit-range-fixed 10 11 2))))
(define c.sub
  (make-instruction
   (list rd_rs1_p rs2_p)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 4) (bit-range-fixed 10 12 3) (bit-range-fixed 5 6 0))))
(define c.xor
  (make-instruction
   (list rd_rs1_p rs2_p)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 4) (bit-range-fixed 10 12 3) (bit-range-fixed 5 6 1))))
(define c.or
  (make-instruction
   (list rd_rs1_p rs2_p)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 4) (bit-range-fixed 10 12 3) (bit-range-fixed 5 6 2))))
(define c.and
  (make-instruction
   (list rd_rs1_p rs2_p)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 4) (bit-range-fixed 10 12 3) (bit-range-fixed 5 6 3))))
(define c.j
  (make-instruction
   (list c_imm12)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 5))))
(define c.beqz
  (make-instruction
   (list rs1_p c_bimm9lo c_bimm9hi)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 6))))
(define c.bnez
  (make-instruction
   (list rs1_p c_bimm9lo c_bimm9hi)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 7))))
(define c.lwsp
  (make-instruction
   (list rd_n0 c_uimm8sphi c_uimm8splo)
   (list (bit-range-fixed 0 1 2) (bit-range-fixed 13 15 2))))
(define c.jr
  (make-instruction
   (list rs1_n0)
   (list (bit-range-fixed 0 1 2) (bit-range-fixed 13 15 4) (bit-range-fixed 12 12 0) (bit-range-fixed 2 6 0))))
(define c.mv
  (make-instruction
   (list rd_n0 c_rs2_n0)
   (list (bit-range-fixed 0 1 2) (bit-range-fixed 13 15 4) (bit-range-fixed 12 12 0))))
(define c.ebreak
  (make-instruction
   (list)
   (list (bit-range-fixed 0 1 2) (bit-range-fixed 13 15 4) (bit-range-fixed 12 12 1) (bit-range-fixed 2 11 0))))
(define c.jalr
  (make-instruction
   (list c_rs1_n0)
   (list (bit-range-fixed 0 1 2) (bit-range-fixed 13 15 4) (bit-range-fixed 12 12 1) (bit-range-fixed 2 6 0))))
(define c.add
  (make-instruction
   (list rd_rs1_n0 c_rs2_n0)
   (list (bit-range-fixed 0 1 2) (bit-range-fixed 13 15 4) (bit-range-fixed 12 12 1))))
(define c.swsp
  (make-instruction
   (list c_rs2 c_uimm8sp_s)
   (list (bit-range-fixed 0 1 2) (bit-range-fixed 13 15 6))))

(provide
 c.addi4spn
 c.lw
 c.sw
 c.nop
 c.addi
 c.li
 c.addi16sp
 c.lui
 c.andi
 c.sub
 c.xor
 c.or
 c.and
 c.j
 c.beqz
 c.bnez
 c.lwsp
 c.jr
 c.mv
 c.ebreak
 c.jalr
 c.add
 c.swsp)
