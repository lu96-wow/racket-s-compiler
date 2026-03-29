#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define sha256sum0 (make-instruction rd rs1 (bit-range-fixed 31 30 0) (bit-range-fixed 29 25 8) (bit-range-fixed 24 20 0) (bit-range-fixed 14 12 1) (bit-range-fixed 6 0 19)))
(define sha256sum1 (make-instruction rd rs1 (bit-range-fixed 31 30 0) (bit-range-fixed 29 25 8) (bit-range-fixed 24 20 1) (bit-range-fixed 14 12 1) (bit-range-fixed 6 0 19)))
(define sha256sig0 (make-instruction rd rs1 (bit-range-fixed 31 30 0) (bit-range-fixed 29 25 8) (bit-range-fixed 24 20 2) (bit-range-fixed 14 12 1) (bit-range-fixed 6 0 19)))
(define sha256sig1 (make-instruction rd rs1 (bit-range-fixed 31 30 0) (bit-range-fixed 29 25 8) (bit-range-fixed 24 20 3) (bit-range-fixed 14 12 1) (bit-range-fixed 6 0 19)))

(provide (all-defined-out))
