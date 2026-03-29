#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define c.flw (make-instruction rd_p rs1_p c_uimm7 (bit-range-fixed 1 0 0) (bit-range-fixed 15 13 3)))
(define c.fsw (make-instruction rs1_p rs2_p c_uimm7 (bit-range-fixed 1 0 0) (bit-range-fixed 15 13 7)))
(define c.flwsp (make-instruction rd c_uimm8sp (bit-range-fixed 1 0 2) (bit-range-fixed 15 13 3)))
(define c.fswsp (make-instruction c_rs2 c_uimm8sp_s (bit-range-fixed 1 0 2) (bit-range-fixed 15 13 7)))

(provide (all-defined-out))
