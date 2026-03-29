#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define add.uw (make-instruction rd rs1 rs2 (bit-range-fixed 31 25 4) (bit-range-fixed 14 12 0) (bit-range-fixed 6 2 14) (bit-range-fixed 1 0 3)))
(define sh1add.uw (make-instruction rd rs1 rs2 (bit-range-fixed 31 25 16) (bit-range-fixed 14 12 2) (bit-range-fixed 6 2 14) (bit-range-fixed 1 0 3)))
(define sh2add.uw (make-instruction rd rs1 rs2 (bit-range-fixed 31 25 16) (bit-range-fixed 14 12 4) (bit-range-fixed 6 2 14) (bit-range-fixed 1 0 3)))
(define sh3add.uw (make-instruction rd rs1 rs2 (bit-range-fixed 31 25 16) (bit-range-fixed 14 12 6) (bit-range-fixed 6 2 14) (bit-range-fixed 1 0 3)))
(define slli.uw (make-instruction rd rs1 shamtd (bit-range-fixed 31 26 2) (bit-range-fixed 14 12 1) (bit-range-fixed 6 2 6) (bit-range-fixed 1 0 3)))

(provide (all-defined-out))
