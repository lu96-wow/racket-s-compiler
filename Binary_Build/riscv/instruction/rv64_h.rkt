#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define hlv.wu (make-instruction rd rs1 (bit-range-fixed 24 20 1) (bit-range-fixed 31 25 52) (bit-range-fixed 14 12 4) (bit-range-fixed 6 2 28) (bit-range-fixed 1 0 3)))
(define hlv.d (make-instruction rd rs1 (bit-range-fixed 24 20 0) (bit-range-fixed 31 25 54) (bit-range-fixed 14 12 4) (bit-range-fixed 6 2 28) (bit-range-fixed 1 0 3)))
(define hsv.d (make-instruction rs1 rs2 (bit-range-fixed 11 7 0) (bit-range-fixed 31 25 55) (bit-range-fixed 14 12 4) (bit-range-fixed 6 2 28) (bit-range-fixed 1 0 3)))

(provide (all-defined-out))
