#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define fcvt.l.h (make-instruction rd rs1 rm (bit-range-fixed 24 20 2) (bit-range-fixed 31 27 24) (bit-range-fixed 26 25 2) (bit-range-fixed 6 2 20) (bit-range-fixed 1 0 3)))
(define fcvt.lu.h (make-instruction rd rs1 rm (bit-range-fixed 24 20 3) (bit-range-fixed 31 27 24) (bit-range-fixed 26 25 2) (bit-range-fixed 6 2 20) (bit-range-fixed 1 0 3)))
(define fcvt.h.l (make-instruction rd rs1 rm (bit-range-fixed 24 20 2) (bit-range-fixed 31 27 26) (bit-range-fixed 26 25 2) (bit-range-fixed 6 2 20) (bit-range-fixed 1 0 3)))
(define fcvt.h.lu (make-instruction rd rs1 rm (bit-range-fixed 24 20 3) (bit-range-fixed 31 27 26) (bit-range-fixed 26 25 2) (bit-range-fixed 6 2 20) (bit-range-fixed 1 0 3)))

(provide (all-defined-out))
