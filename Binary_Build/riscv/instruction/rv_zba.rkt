#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define sh1add (make-instruction rd rs1 rs2 (bit-range-fixed 31 25 16) (bit-range-fixed 14 12 2) (bit-range-fixed 6 2 12) (bit-range-fixed 1 0 3)))
(define sh2add (make-instruction rd rs1 rs2 (bit-range-fixed 31 25 16) (bit-range-fixed 14 12 4) (bit-range-fixed 6 2 12) (bit-range-fixed 1 0 3)))
(define sh3add (make-instruction rd rs1 rs2 (bit-range-fixed 31 25 16) (bit-range-fixed 14 12 6) (bit-range-fixed 6 2 12) (bit-range-fixed 1 0 3)))

(provide (all-defined-out))
