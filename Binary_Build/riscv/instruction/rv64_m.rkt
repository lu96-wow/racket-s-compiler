#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define mulw (make-instruction rd rs1 rs2 (bit-range-fixed 31 25 1) (bit-range-fixed 14 12 0) (bit-range-fixed 6 2 14) (bit-range-fixed 1 0 3)))
(define divw (make-instruction rd rs1 rs2 (bit-range-fixed 31 25 1) (bit-range-fixed 14 12 4) (bit-range-fixed 6 2 14) (bit-range-fixed 1 0 3)))
(define divuw (make-instruction rd rs1 rs2 (bit-range-fixed 31 25 1) (bit-range-fixed 14 12 5) (bit-range-fixed 6 2 14) (bit-range-fixed 1 0 3)))
(define remw (make-instruction rd rs1 rs2 (bit-range-fixed 31 25 1) (bit-range-fixed 14 12 6) (bit-range-fixed 6 2 14) (bit-range-fixed 1 0 3)))
(define remuw (make-instruction rd rs1 rs2 (bit-range-fixed 31 25 1) (bit-range-fixed 14 12 7) (bit-range-fixed 6 2 14) (bit-range-fixed 1 0 3)))

(provide (all-defined-out))
