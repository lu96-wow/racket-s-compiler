#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define c.lbu (make-instruction rd_p rs1_p c_uimm2 (bit-range-fixed 1 0 0) (bit-range-fixed 15 13 4) (bit-range-fixed 12 10 0)))
(define c.lhu (make-instruction rd_p rs1_p c_uimm1 (bit-range-fixed 1 0 0) (bit-range-fixed 15 13 4) (bit-range-fixed 12 10 1) (bit-range-fixed 6 6 0)))
(define c.lh (make-instruction rd_p rs1_p c_uimm1 (bit-range-fixed 1 0 0) (bit-range-fixed 15 13 4) (bit-range-fixed 12 10 1) (bit-range-fixed 6 6 1)))
(define c.sb (make-instruction rs2_p rs1_p c_uimm2 (bit-range-fixed 1 0 0) (bit-range-fixed 15 13 4) (bit-range-fixed 12 10 2)))
(define c.sh (make-instruction rs2_p rs1_p c_uimm1 (bit-range-fixed 1 0 0) (bit-range-fixed 15 13 4) (bit-range-fixed 12 10 3) (bit-range-fixed 6 6 0)))
(define c.zext.b (make-instruction rd_rs1_p (bit-range-fixed 1 0 1) (bit-range-fixed 15 13 4) (bit-range-fixed 12 10 7) (bit-range-fixed 6 5 3) (bit-range-fixed 4 2 0)))
(define c.sext.b (make-instruction rd_rs1_p (bit-range-fixed 1 0 1) (bit-range-fixed 15 13 4) (bit-range-fixed 12 10 7) (bit-range-fixed 6 5 3) (bit-range-fixed 4 2 1)))
(define c.zext.h (make-instruction rd_rs1_p (bit-range-fixed 1 0 1) (bit-range-fixed 15 13 4) (bit-range-fixed 12 10 7) (bit-range-fixed 6 5 3) (bit-range-fixed 4 2 2)))
(define c.sext.h (make-instruction rd_rs1_p (bit-range-fixed 1 0 1) (bit-range-fixed 15 13 4) (bit-range-fixed 12 10 7) (bit-range-fixed 6 5 3) (bit-range-fixed 4 2 3)))
(define c.not (make-instruction rd_rs1_p (bit-range-fixed 1 0 1) (bit-range-fixed 15 13 4) (bit-range-fixed 12 10 7) (bit-range-fixed 6 5 3) (bit-range-fixed 4 2 5)))
(define c.mul (make-instruction rd_rs1_p rs2_p (bit-range-fixed 1 0 1) (bit-range-fixed 15 13 4) (bit-range-fixed 12 10 7) (bit-range-fixed 6 5 2)))

(provide (all-defined-out))
