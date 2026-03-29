#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define aes32esmi (make-instruction rd rs1 rs2 bs (bit-range-fixed 29 25 19) (bit-range-fixed 14 12 0) (bit-range-fixed 6 0 51)))
(define aes32esi (make-instruction rd rs1 rs2 bs (bit-range-fixed 29 25 17) (bit-range-fixed 14 12 0) (bit-range-fixed 6 0 51)))

(provide (all-defined-out))
