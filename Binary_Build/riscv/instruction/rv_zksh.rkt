#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define sm3p0 (make-instruction rd rs1 (bit-range-fixed 31 30 0) (bit-range-fixed 29 25 8) (bit-range-fixed 24 20 8) (bit-range-fixed 14 12 1) (bit-range-fixed 6 0 19)))
(define sm3p1 (make-instruction rd rs1 (bit-range-fixed 31 30 0) (bit-range-fixed 29 25 8) (bit-range-fixed 24 20 9) (bit-range-fixed 14 12 1) (bit-range-fixed 6 0 19)))

(provide (all-defined-out))
