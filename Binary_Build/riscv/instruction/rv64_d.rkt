#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define fcvt.l.d (make-instruction rd rs1 rm (bit-range-fixed 24 20 2) (bit-range-fixed 31 27 24) (bit-range-fixed 26 25 1) (bit-range-fixed 6 2 20) (bit-range-fixed 1 0 3)))
(define fcvt.lu.d (make-instruction rd rs1 rm (bit-range-fixed 24 20 3) (bit-range-fixed 31 27 24) (bit-range-fixed 26 25 1) (bit-range-fixed 6 2 20) (bit-range-fixed 1 0 3)))
(define fmv.x.d (make-instruction rd rs1 (bit-range-fixed 24 20 0) (bit-range-fixed 31 27 28) (bit-range-fixed 14 12 0) (bit-range-fixed 26 25 1) (bit-range-fixed 6 2 20) (bit-range-fixed 1 0 3)))
(define fcvt.d.l (make-instruction rd rs1 rm (bit-range-fixed 24 20 2) (bit-range-fixed 31 27 26) (bit-range-fixed 26 25 1) (bit-range-fixed 6 2 20) (bit-range-fixed 1 0 3)))
(define fcvt.d.lu (make-instruction rd rs1 rm (bit-range-fixed 24 20 3) (bit-range-fixed 31 27 26) (bit-range-fixed 26 25 1) (bit-range-fixed 6 2 20) (bit-range-fixed 1 0 3)))
(define fmv.d.x (make-instruction rd rs1 (bit-range-fixed 24 20 0) (bit-range-fixed 31 27 30) (bit-range-fixed 14 12 0) (bit-range-fixed 26 25 1) (bit-range-fixed 6 2 20) (bit-range-fixed 1 0 3)))

(provide (all-defined-out))
