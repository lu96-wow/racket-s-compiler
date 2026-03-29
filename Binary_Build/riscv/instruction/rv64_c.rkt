#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define c.ld (make-instruction rd_p rs1_p c_uimm8 (bit-range-fixed 1 0 0) (bit-range-fixed 15 13 3)))
(define c.sd (make-instruction rs1_p rs2_p c_uimm8 (bit-range-fixed 1 0 0) (bit-range-fixed 15 13 7)))
(define c.addiw (make-instruction rd_rs1_n0 c_imm6 (bit-range-fixed 1 0 1) (bit-range-fixed 15 13 1)))
(define c.srli (make-instruction rd_rs1_p c_nzuimm6 (bit-range-fixed 1 0 1) (bit-range-fixed 15 13 4) (bit-range-fixed 11 10 0)))
(define c.srai (make-instruction rd_rs1_p c_nzuimm6 (bit-range-fixed 1 0 1) (bit-range-fixed 15 13 4) (bit-range-fixed 11 10 1)))
(define c.subw (make-instruction rd_rs1_p rs2_p (bit-range-fixed 1 0 1) (bit-range-fixed 15 13 4) (bit-range-fixed 12 10 7) (bit-range-fixed 6 5 0)))
(define c.addw (make-instruction rd_rs1_p rs2_p (bit-range-fixed 1 0 1) (bit-range-fixed 15 13 4) (bit-range-fixed 12 10 7) (bit-range-fixed 6 5 1)))
(define c.slli (make-instruction rd_rs1_n0 c_nzuimm6 (bit-range-fixed 1 0 2) (bit-range-fixed 15 13 0)))
(define c.ldsp (make-instruction rd_n0 c_uimm9sp (bit-range-fixed 1 0 2) (bit-range-fixed 15 13 3)))
(define c.sdsp (make-instruction c_rs2 c_uimm9sp_s (bit-range-fixed 1 0 2) (bit-range-fixed 15 13 7)))

(provide (all-defined-out))
