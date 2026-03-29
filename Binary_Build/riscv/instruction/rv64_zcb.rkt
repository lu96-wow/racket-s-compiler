#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define c.zext.w (make-instruction rd_rs1_p (bit-range-fixed 1 0 1) (bit-range-fixed 15 13 4) (bit-range-fixed 12 10 7) (bit-range-fixed 6 5 3) (bit-range-fixed 4 2 4)))

(provide (all-defined-out))
