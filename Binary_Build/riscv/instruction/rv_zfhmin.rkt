#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define flh (make-instruction rd rs1 imm12 (bit-range-fixed 14 12 1) (bit-range-fixed 6 2 1) (bit-range-fixed 1 0 3)))
(define fsh (make-instruction imm12 rs1 rs2 (bit-range-fixed 14 12 1) (bit-range-fixed 6 2 9) (bit-range-fixed 1 0 3)))
(define fcvt.s.h (make-instruction rd rs1 rm (bit-range-fixed 24 20 2) (bit-range-fixed 31 27 8) (bit-range-fixed 26 25 0) (bit-range-fixed 6 2 20) (bit-range-fixed 1 0 3)))
(define fcvt.h.s (make-instruction rd rs1 rm (bit-range-fixed 24 20 0) (bit-range-fixed 31 27 8) (bit-range-fixed 26 25 2) (bit-range-fixed 6 2 20) (bit-range-fixed 1 0 3)))
(define fmv.x.h (make-instruction rd rs1 (bit-range-fixed 24 20 0) (bit-range-fixed 31 27 28) (bit-range-fixed 14 12 0) (bit-range-fixed 26 25 2) (bit-range-fixed 6 2 20) (bit-range-fixed 1 0 3)))
(define fmv.h.x (make-instruction rd rs1 (bit-range-fixed 24 20 0) (bit-range-fixed 31 27 30) (bit-range-fixed 14 12 0) (bit-range-fixed 26 25 2) (bit-range-fixed 6 2 20) (bit-range-fixed 1 0 3)))

(provide (all-defined-out))
