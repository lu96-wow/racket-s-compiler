#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define sha512sum0 (make-instruction rd rs1 (bit-range-fixed 31 30 0) (bit-range-fixed 29 25 8) (bit-range-fixed 24 20 4) (bit-range-fixed 14 12 1) (bit-range-fixed 6 0 19)))
(define sha512sum1 (make-instruction rd rs1 (bit-range-fixed 31 30 0) (bit-range-fixed 29 25 8) (bit-range-fixed 24 20 5) (bit-range-fixed 14 12 1) (bit-range-fixed 6 0 19)))
(define sha512sig0 (make-instruction rd rs1 (bit-range-fixed 31 30 0) (bit-range-fixed 29 25 8) (bit-range-fixed 24 20 6) (bit-range-fixed 14 12 1) (bit-range-fixed 6 0 19)))
(define sha512sig1 (make-instruction rd rs1 (bit-range-fixed 31 30 0) (bit-range-fixed 29 25 8) (bit-range-fixed 24 20 7) (bit-range-fixed 14 12 1) (bit-range-fixed 6 0 19)))

(provide (all-defined-out))
