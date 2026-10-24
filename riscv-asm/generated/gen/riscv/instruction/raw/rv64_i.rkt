#lang racket/base

(require "../../../../lib/base.rkt"
         "../../../../lib/riscv/raw/scalar.rkt"
         "../../../../lib/riscv/raw/compressed.rkt"
         "../../../../lib/riscv/raw/vector.rkt"
         "../../../../lib/riscv/raw/mop.rkt")

(define lwu
  (make-instruction
   (list rd rs1 imm12)
   (list (bit-range-fixed 12 14 6) (bit-range-fixed 2 6 0) (bit-range-fixed 0 1 3))))
(define ld
  (make-instruction
   (list rd rs1 imm12)
   (list (bit-range-fixed 12 14 3) (bit-range-fixed 2 6 0) (bit-range-fixed 0 1 3))))
(define sd
  (make-instruction
   (list imm12hi rs1 rs2 imm12lo)
   (list (bit-range-fixed 12 14 3) (bit-range-fixed 2 6 8) (bit-range-fixed 0 1 3))))
(define slli
  (make-instruction
   (list rd rs1 shamtd)
   (list (bit-range-fixed 26 31 0) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define srli
  (make-instruction
   (list rd rs1 shamtd)
   (list (bit-range-fixed 26 31 0) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define srai
  (make-instruction
   (list rd rs1 shamtd)
   (list (bit-range-fixed 26 31 16) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define addiw
  (make-instruction
   (list rd rs1 imm12)
   (list (bit-range-fixed 12 14 0) (bit-range-fixed 2 6 6) (bit-range-fixed 0 1 3))))
(define slliw
  (make-instruction
   (list rd rs1 shamtw)
   (list (bit-range-fixed 25 31 0) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 6) (bit-range-fixed 0 1 3))))
(define srliw
  (make-instruction
   (list rd rs1 shamtw)
   (list (bit-range-fixed 25 31 0) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 6) (bit-range-fixed 0 1 3))))
(define sraiw
  (make-instruction
   (list rd rs1 shamtw)
   (list (bit-range-fixed 25 31 32) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 6) (bit-range-fixed 0 1 3))))
(define addw
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 25 31 0) (bit-range-fixed 12 14 0) (bit-range-fixed 2 6 14) (bit-range-fixed 0 1 3))))
(define subw
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 25 31 32) (bit-range-fixed 12 14 0) (bit-range-fixed 2 6 14) (bit-range-fixed 0 1 3))))
(define sllw
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 25 31 0) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 14) (bit-range-fixed 0 1 3))))
(define srlw
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 25 31 0) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 14) (bit-range-fixed 0 1 3))))
(define sraw
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 25 31 32) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 14) (bit-range-fixed 0 1 3))))
(define sext.w
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 20 31 0) (bit-range-fixed 12 14 0) (bit-range-fixed 2 6 6) (bit-range-fixed 0 1 3))))

(provide
 lwu
 ld
 sd
 slli
 srli
 srai
 addiw
 slliw
 srliw
 sraiw
 addw
 subw
 sllw
 srlw
 sraw
 sext.w)
