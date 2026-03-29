#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define wrs.nto (make-instruction (bit-range-fixed 31 20 13) (bit-range-fixed 19 7 0) (bit-range-fixed 6 2 28) (bit-range-fixed 1 0 3)))
(define wrs.sto (make-instruction (bit-range-fixed 31 20 29) (bit-range-fixed 19 7 0) (bit-range-fixed 6 2 28) (bit-range-fixed 1 0 3)))

(provide (all-defined-out))
