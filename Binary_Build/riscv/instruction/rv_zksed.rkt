#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define sm4ed (make-instruction rd rs1 rs2 bs (bit-range-fixed 29 25 24) (bit-range-fixed 14 12 0) (bit-range-fixed 6 0 51)))
(define sm4ks (make-instruction rd rs1 rs2 bs (bit-range-fixed 29 25 26) (bit-range-fixed 14 12 0) (bit-range-fixed 6 0 51)))

(provide (all-defined-out))
