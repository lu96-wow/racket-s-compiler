#lang racket/base

(require "../../../../lib/base.rkt"
         "../../../../lib/riscv/raw/scalar.rkt"
         "../../../../lib/riscv/raw/compressed.rkt"
         "../../../../lib/riscv/raw/vector.rkt"
         "../../../../lib/riscv/raw/mop.rkt")

(define c.jal
  (make-instruction
   (list c_imm12)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 1))))
(define c.srli
  (make-instruction
   (list rd_rs1_p c_nzuimm5)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 4) (bit-range-fixed 10 12 0))))
(define c.srai
  (make-instruction
   (list rd_rs1_p c_nzuimm5)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 4) (bit-range-fixed 10 12 1))))
(define c.slli
  (make-instruction
   (list rd_rs1_n0 c_nzuimm6lo)
   (list (bit-range-fixed 0 1 2) (bit-range-fixed 12 15 0))))
(define c.srli_rv32
  (make-instruction
   (list rd_rs1_p c_nzuimm5)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 4) (bit-range-fixed 10 12 0))))
(define c.srai_rv32
  (make-instruction
   (list rd_rs1_p c_nzuimm5)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 4) (bit-range-fixed 10 12 1))))
(define c.slli_rv32
  (make-instruction
   (list rd_rs1_n0 c_nzuimm6lo)
   (list (bit-range-fixed 0 1 2) (bit-range-fixed 12 15 0))))

(provide
 c.jal
 c.srli
 c.srai
 c.slli
 c.srli_rv32
 c.srai_rv32
 c.slli_rv32)
