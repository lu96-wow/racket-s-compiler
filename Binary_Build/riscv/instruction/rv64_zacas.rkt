#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define amocas.q (make-instruction rd rs1 rs2 aq rl (bit-range-fixed 31 29 1) (bit-range-fixed 28 27 1) (bit-range-fixed 14 12 4) (bit-range-fixed 6 2 11) (bit-range-fixed 1 0 3)))

(provide (all-defined-out))
