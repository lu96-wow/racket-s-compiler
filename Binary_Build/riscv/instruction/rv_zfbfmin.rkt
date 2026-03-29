#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define fcvt.bf16.s (make-instruction rd rs1 rm (bit-range-fixed 24 20 8) (bit-range-fixed 31 27 8) (bit-range-fixed 26 25 2) (bit-range-fixed 6 2 20) (bit-range-fixed 1 0 3)))
(define fcvt.s.bf16 (make-instruction rd rs1 rm (bit-range-fixed 24 20 6) (bit-range-fixed 31 27 8) (bit-range-fixed 26 25 0) (bit-range-fixed 6 2 20) (bit-range-fixed 1 0 3)))

(provide (all-defined-out))
