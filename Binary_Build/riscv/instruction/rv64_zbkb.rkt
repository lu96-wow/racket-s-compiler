#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define packw (make-instruction rd rs1 rs2 (bit-range-fixed 31 25 4) (bit-range-fixed 14 12 4) (bit-range-fixed 6 2 14) (bit-range-fixed 1 0 3)))

(provide (all-defined-out))
