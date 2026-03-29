#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define clmul (make-instruction rd rs1 rs2 (bit-range-fixed 31 25 5) (bit-range-fixed 14 12 1) (bit-range-fixed 6 2 12) (bit-range-fixed 1 0 3)))
(define clmulr (make-instruction rd rs1 rs2 (bit-range-fixed 31 25 5) (bit-range-fixed 14 12 2) (bit-range-fixed 6 2 12) (bit-range-fixed 1 0 3)))
(define clmulh (make-instruction rd rs1 rs2 (bit-range-fixed 31 25 5) (bit-range-fixed 14 12 3) (bit-range-fixed 6 2 12) (bit-range-fixed 1 0 3)))

(provide (all-defined-out))
