#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define aes32dsmi (make-instruction rd rs1 rs2 bs (bit-range-fixed 29 25 23) (bit-range-fixed 14 12 0) (bit-range-fixed 6 0 51)))
(define aes32dsi (make-instruction rd rs1 rs2 bs (bit-range-fixed 29 25 21) (bit-range-fixed 14 12 0) (bit-range-fixed 6 0 51)))

(provide (all-defined-out))
