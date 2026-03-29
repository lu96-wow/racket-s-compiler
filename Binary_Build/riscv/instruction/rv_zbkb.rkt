#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define pack (make-instruction rd rs1 rs2 (bit-range-fixed 31 25 4) (bit-range-fixed 14 12 4) (bit-range-fixed 6 2 12) (bit-range-fixed 1 0 3)))
(define packh (make-instruction rd rs1 rs2 (bit-range-fixed 31 25 4) (bit-range-fixed 14 12 7) (bit-range-fixed 6 2 12) (bit-range-fixed 1 0 3)))
(define brev8 (make-instruction rd rs1 (bit-range-fixed 31 20 1671) (bit-range-fixed 14 12 5) (bit-range-fixed 6 2 4) (bit-range-fixed 1 0 3)))

(provide (all-defined-out))
