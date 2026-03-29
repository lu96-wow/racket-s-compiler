#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define cbo.clean (make-instruction rs1 (bit-range-fixed 31 20 1) (bit-range-fixed 14 12 2) (bit-range-fixed 11 7 0) (bit-range-fixed 6 2 3) (bit-range-fixed 1 0 3)))
(define cbo.flush (make-instruction rs1 (bit-range-fixed 31 20 2) (bit-range-fixed 14 12 2) (bit-range-fixed 11 7 0) (bit-range-fixed 6 2 3) (bit-range-fixed 1 0 3)))
(define cbo.inval (make-instruction rs1 (bit-range-fixed 31 20 0) (bit-range-fixed 14 12 2) (bit-range-fixed 11 7 0) (bit-range-fixed 6 2 3) (bit-range-fixed 1 0 3)))
(define cbo.zero (make-instruction rs1 (bit-range-fixed 31 20 4) (bit-range-fixed 14 12 2) (bit-range-fixed 11 7 0) (bit-range-fixed 6 2 3) (bit-range-fixed 1 0 3)))

(provide (all-defined-out))
