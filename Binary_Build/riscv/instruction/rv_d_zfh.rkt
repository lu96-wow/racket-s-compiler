#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define fcvt.d.h (make-instruction rd rs1 rm (bit-range-fixed 24 20 2) (bit-range-fixed 31 27 8) (bit-range-fixed 26 25 1) (bit-range-fixed 6 2 20) (bit-range-fixed 1 0 3)))
(define fcvt.h.d (make-instruction rd rs1 rm (bit-range-fixed 24 20 1) (bit-range-fixed 31 27 8) (bit-range-fixed 26 25 2) (bit-range-fixed 6 2 20) (bit-range-fixed 1 0 3)))

(provide (all-defined-out))
