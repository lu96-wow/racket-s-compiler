#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define c.mop.N (make-instruction c_mop_t (bit-range-fixed 1 0 1) (bit-range-fixed 6 2 0) (bit-range-fixed 11 11 0) (bit-range-fixed 7 7 1) (bit-range-fixed 12 12 0) (bit-range-fixed 15 13 3)))

(provide (all-defined-out))
