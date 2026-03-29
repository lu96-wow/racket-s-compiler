#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define mret (make-instruction (bit-range-fixed 11 7 0) (bit-range-fixed 19 15 0) (bit-range-fixed 31 20 770) (bit-range-fixed 14 12 0) (bit-range-fixed 6 2 28) (bit-range-fixed 1 0 3)))
(define wfi (make-instruction (bit-range-fixed 11 7 0) (bit-range-fixed 19 15 0) (bit-range-fixed 31 20 261) (bit-range-fixed 14 12 0) (bit-range-fixed 6 2 28) (bit-range-fixed 1 0 3)))

(provide (all-defined-out))
