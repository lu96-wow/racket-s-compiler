#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define c.fld (make-instruction rd_p rs1_p c_uimm8 (bit-range-fixed 1 0 0) (bit-range-fixed 15 13 1)))
(define c.fsd (make-instruction rs1_p rs2_p c_uimm8 (bit-range-fixed 1 0 0) (bit-range-fixed 15 13 5)))
(define c.fldsp (make-instruction rd c_uimm9sp (bit-range-fixed 1 0 2) (bit-range-fixed 15 13 1)))
(define c.fsdsp (make-instruction c_rs2 c_uimm9sp_s (bit-range-fixed 1 0 2) (bit-range-fixed 15 13 5)))

(provide (all-defined-out))
