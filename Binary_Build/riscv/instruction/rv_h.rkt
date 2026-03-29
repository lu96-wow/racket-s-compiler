#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define hfence.vvma (make-instruction rs1 rs2 (bit-range-fixed 11 7 0) (bit-range-fixed 31 25 17) (bit-range-fixed 14 12 0) (bit-range-fixed 6 2 28) (bit-range-fixed 1 0 3)))
(define hfence.gvma (make-instruction rs1 rs2 (bit-range-fixed 11 7 0) (bit-range-fixed 31 25 49) (bit-range-fixed 14 12 0) (bit-range-fixed 6 2 28) (bit-range-fixed 1 0 3)))
(define hlv.b (make-instruction rd rs1 (bit-range-fixed 24 20 0) (bit-range-fixed 31 25 48) (bit-range-fixed 14 12 4) (bit-range-fixed 6 2 28) (bit-range-fixed 1 0 3)))
(define hlv.bu (make-instruction rd rs1 (bit-range-fixed 24 20 1) (bit-range-fixed 31 25 48) (bit-range-fixed 14 12 4) (bit-range-fixed 6 2 28) (bit-range-fixed 1 0 3)))
(define hlv.h (make-instruction rd rs1 (bit-range-fixed 24 20 0) (bit-range-fixed 31 25 50) (bit-range-fixed 14 12 4) (bit-range-fixed 6 2 28) (bit-range-fixed 1 0 3)))
(define hlv.hu (make-instruction rd rs1 (bit-range-fixed 24 20 1) (bit-range-fixed 31 25 50) (bit-range-fixed 14 12 4) (bit-range-fixed 6 2 28) (bit-range-fixed 1 0 3)))
(define hlvx.hu (make-instruction rd rs1 (bit-range-fixed 24 20 3) (bit-range-fixed 31 25 50) (bit-range-fixed 14 12 4) (bit-range-fixed 6 2 28) (bit-range-fixed 1 0 3)))
(define hlv.w (make-instruction rd rs1 (bit-range-fixed 24 20 0) (bit-range-fixed 31 25 52) (bit-range-fixed 14 12 4) (bit-range-fixed 6 2 28) (bit-range-fixed 1 0 3)))
(define hlvx.wu (make-instruction rd rs1 (bit-range-fixed 24 20 3) (bit-range-fixed 31 25 52) (bit-range-fixed 14 12 4) (bit-range-fixed 6 2 28) (bit-range-fixed 1 0 3)))
(define hsv.b (make-instruction rs1 rs2 (bit-range-fixed 11 7 0) (bit-range-fixed 31 25 49) (bit-range-fixed 14 12 4) (bit-range-fixed 6 2 28) (bit-range-fixed 1 0 3)))
(define hsv.h (make-instruction rs1 rs2 (bit-range-fixed 11 7 0) (bit-range-fixed 31 25 51) (bit-range-fixed 14 12 4) (bit-range-fixed 6 2 28) (bit-range-fixed 1 0 3)))
(define hsv.w (make-instruction rs1 rs2 (bit-range-fixed 11 7 0) (bit-range-fixed 31 25 53) (bit-range-fixed 14 12 4) (bit-range-fixed 6 2 28) (bit-range-fixed 1 0 3)))

(provide (all-defined-out))
