#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define sha512sum0r (make-instruction rd rs1 rs2 (bit-range-fixed 31 30 1) (bit-range-fixed 29 25 8) (bit-range-fixed 14 12 0) (bit-range-fixed 6 0 51)))
(define sha512sum1r (make-instruction rd rs1 rs2 (bit-range-fixed 31 30 1) (bit-range-fixed 29 25 9) (bit-range-fixed 14 12 0) (bit-range-fixed 6 0 51)))
(define sha512sig0l (make-instruction rd rs1 rs2 (bit-range-fixed 31 30 1) (bit-range-fixed 29 25 10) (bit-range-fixed 14 12 0) (bit-range-fixed 6 0 51)))
(define sha512sig0h (make-instruction rd rs1 rs2 (bit-range-fixed 31 30 1) (bit-range-fixed 29 25 14) (bit-range-fixed 14 12 0) (bit-range-fixed 6 0 51)))
(define sha512sig1l (make-instruction rd rs1 rs2 (bit-range-fixed 31 30 1) (bit-range-fixed 29 25 11) (bit-range-fixed 14 12 0) (bit-range-fixed 6 0 51)))
(define sha512sig1h (make-instruction rd rs1 rs2 (bit-range-fixed 31 30 1) (bit-range-fixed 29 25 15) (bit-range-fixed 14 12 0) (bit-range-fixed 6 0 51)))

(provide (all-defined-out))
