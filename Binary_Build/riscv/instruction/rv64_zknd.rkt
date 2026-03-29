#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define aes64dsm (make-instruction rd rs1 rs2 (bit-range-fixed 31 30 0) (bit-range-fixed 29 25 31) (bit-range-fixed 14 12 0) (bit-range-fixed 6 0 51)))
(define aes64ds (make-instruction rd rs1 rs2 (bit-range-fixed 31 30 0) (bit-range-fixed 29 25 29) (bit-range-fixed 14 12 0) (bit-range-fixed 6 0 51)))
(define aes64ks1i (make-instruction rd rs1 rnum 24=1 (bit-range-fixed 31 30 0) (bit-range-fixed 29 25 24) (bit-range-fixed 14 12 1) (bit-range-fixed 6 0 19)))
(define aes64im (make-instruction rd rs1 (bit-range-fixed 31 30 0) (bit-range-fixed 29 25 24) (bit-range-fixed 24 20 0) (bit-range-fixed 14 12 1) (bit-range-fixed 6 0 19)))
(define aes64ks2 (make-instruction rd rs1 rs2 (bit-range-fixed 31 30 1) (bit-range-fixed 29 25 31) (bit-range-fixed 14 12 0) (bit-range-fixed 6 0 51)))

(provide (all-defined-out))
