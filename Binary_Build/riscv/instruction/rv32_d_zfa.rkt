#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define fmvh.x.d (make-instruction rd rs1 (bit-range-fixed 24 20 1) (bit-range-fixed 31 27 28) (bit-range-fixed 14 12 0) (bit-range-fixed 26 25 1) (bit-range-fixed 6 2 20) (bit-range-fixed 1 0 3)))
(define fmvp.d.x (make-instruction rd rs1 rs2 (bit-range-fixed 31 27 22) (bit-range-fixed 14 12 0) (bit-range-fixed 26 25 1) (bit-range-fixed 6 2 20) (bit-range-fixed 1 0 3)))

(provide (all-defined-out))
