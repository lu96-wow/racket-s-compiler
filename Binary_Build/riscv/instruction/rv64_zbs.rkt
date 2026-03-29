#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define bclri (make-instruction rd rs1 shamtd (bit-range-fixed 31 26 18) (bit-range-fixed 14 12 1) (bit-range-fixed 6 2 4) (bit-range-fixed 1 0 3)))
(define bexti (make-instruction rd rs1 shamtd (bit-range-fixed 31 26 18) (bit-range-fixed 14 12 5) (bit-range-fixed 6 2 4) (bit-range-fixed 1 0 3)))
(define binvi (make-instruction rd rs1 shamtd (bit-range-fixed 31 26 26) (bit-range-fixed 14 12 1) (bit-range-fixed 6 2 4) (bit-range-fixed 1 0 3)))
(define bseti (make-instruction rd rs1 shamtd (bit-range-fixed 31 26 10) (bit-range-fixed 14 12 1) (bit-range-fixed 6 2 4) (bit-range-fixed 1 0 3)))

(provide (all-defined-out))
