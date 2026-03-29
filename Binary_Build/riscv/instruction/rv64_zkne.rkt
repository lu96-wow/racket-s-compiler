#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define aes64esm (make-instruction rd rs1 rs2 (bit-range-fixed 31 30 0) (bit-range-fixed 29 25 27) (bit-range-fixed 14 12 0) (bit-range-fixed 6 0 51)))
(define aes64es (make-instruction rd rs1 rs2 (bit-range-fixed 31 30 0) (bit-range-fixed 29 25 25) (bit-range-fixed 14 12 0) (bit-range-fixed 6 0 51)))

(provide (all-defined-out))
