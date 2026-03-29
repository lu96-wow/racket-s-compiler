#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define bclr (make-instruction rd rs1 rs2 (bit-range-fixed 31 25 36) (bit-range-fixed 14 12 1) (bit-range-fixed 6 2 12) (bit-range-fixed 1 0 3)))
(define bext (make-instruction rd rs1 rs2 (bit-range-fixed 31 25 36) (bit-range-fixed 14 12 5) (bit-range-fixed 6 2 12) (bit-range-fixed 1 0 3)))
(define binv (make-instruction rd rs1 rs2 (bit-range-fixed 31 25 52) (bit-range-fixed 14 12 1) (bit-range-fixed 6 2 12) (bit-range-fixed 1 0 3)))
(define bset (make-instruction rd rs1 rs2 (bit-range-fixed 31 25 20) (bit-range-fixed 14 12 1) (bit-range-fixed 6 2 12) (bit-range-fixed 1 0 3)))

(provide (all-defined-out))
