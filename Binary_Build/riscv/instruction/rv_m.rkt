#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define mul (make-instruction rd rs1 rs2 (bit-range-fixed 31 25 1) (bit-range-fixed 14 12 0) (bit-range-fixed 6 2 12) (bit-range-fixed 1 0 3)))
(define mulh (make-instruction rd rs1 rs2 (bit-range-fixed 31 25 1) (bit-range-fixed 14 12 1) (bit-range-fixed 6 2 12) (bit-range-fixed 1 0 3)))
(define mulhsu (make-instruction rd rs1 rs2 (bit-range-fixed 31 25 1) (bit-range-fixed 14 12 2) (bit-range-fixed 6 2 12) (bit-range-fixed 1 0 3)))
(define mulhu (make-instruction rd rs1 rs2 (bit-range-fixed 31 25 1) (bit-range-fixed 14 12 3) (bit-range-fixed 6 2 12) (bit-range-fixed 1 0 3)))
(define div (make-instruction rd rs1 rs2 (bit-range-fixed 31 25 1) (bit-range-fixed 14 12 4) (bit-range-fixed 6 2 12) (bit-range-fixed 1 0 3)))
(define divu (make-instruction rd rs1 rs2 (bit-range-fixed 31 25 1) (bit-range-fixed 14 12 5) (bit-range-fixed 6 2 12) (bit-range-fixed 1 0 3)))
(define rem (make-instruction rd rs1 rs2 (bit-range-fixed 31 25 1) (bit-range-fixed 14 12 6) (bit-range-fixed 6 2 12) (bit-range-fixed 1 0 3)))
(define remu (make-instruction rd rs1 rs2 (bit-range-fixed 31 25 1) (bit-range-fixed 14 12 7) (bit-range-fixed 6 2 12) (bit-range-fixed 1 0 3)))

(provide (all-defined-out))
