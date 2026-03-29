#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define zip (make-instruction rd rs1 (bit-range-fixed 31 25 4) (bit-range-fixed 24 20 15) (bit-range-fixed 14 12 1) (bit-range-fixed 6 2 4) (bit-range-fixed 1 0 3)))
(define unzip (make-instruction rd rs1 (bit-range-fixed 31 25 4) (bit-range-fixed 24 20 15) (bit-range-fixed 14 12 5) (bit-range-fixed 6 2 4) (bit-range-fixed 1 0 3)))
(define rev8.rv32 (make-instruction rd rs1 (bit-range-fixed 31 20 1688) (bit-range-fixed 14 12 5) (bit-range-fixed 6 0 19)))

(provide (all-defined-out))
