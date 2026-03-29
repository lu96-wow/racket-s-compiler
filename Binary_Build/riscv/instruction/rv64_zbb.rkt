#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define clzw (make-instruction rd rs1 (bit-range-fixed 31 20 1536) (bit-range-fixed 14 12 1) (bit-range-fixed 6 2 6) (bit-range-fixed 1 0 3)))
(define ctzw (make-instruction rd rs1 (bit-range-fixed 31 20 1537) (bit-range-fixed 14 12 1) (bit-range-fixed 6 2 6) (bit-range-fixed 1 0 3)))
(define cpopw (make-instruction rd rs1 (bit-range-fixed 31 20 1538) (bit-range-fixed 14 12 1) (bit-range-fixed 6 2 6) (bit-range-fixed 1 0 3)))
(define rolw (make-instruction rd rs1 rs2 (bit-range-fixed 31 25 48) (bit-range-fixed 14 12 1) (bit-range-fixed 6 2 14) (bit-range-fixed 1 0 3)))
(define rorw (make-instruction rd rs1 rs2 (bit-range-fixed 31 25 48) (bit-range-fixed 14 12 5) (bit-range-fixed 6 2 14) (bit-range-fixed 1 0 3)))
(define roriw (make-instruction rd rs1 shamtw (bit-range-fixed 31 25 48) (bit-range-fixed 14 12 5) (bit-range-fixed 6 2 6) (bit-range-fixed 1 0 3)))
(define rori (make-instruction rd rs1 shamtd (bit-range-fixed 31 26 24) (bit-range-fixed 14 12 5) (bit-range-fixed 6 2 4) (bit-range-fixed 1 0 3)))
(define rev8 (make-instruction rd rs1 (bit-range-fixed 31 20 1720) (bit-range-fixed 14 12 5) (bit-range-fixed 6 0 19)))

(provide (all-defined-out))
