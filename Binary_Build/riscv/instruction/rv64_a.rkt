#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define lr.d (make-instruction rd rs1 aq rl (bit-range-fixed 24 20 0) (bit-range-fixed 31 29 0) (bit-range-fixed 28 27 2) (bit-range-fixed 14 12 3) (bit-range-fixed 6 2 11) (bit-range-fixed 1 0 3)))
(define sc.d (make-instruction rd rs1 rs2 aq rl (bit-range-fixed 31 29 0) (bit-range-fixed 28 27 3) (bit-range-fixed 14 12 3) (bit-range-fixed 6 2 11) (bit-range-fixed 1 0 3)))
(define amoswap.d (make-instruction rd rs1 rs2 aq rl (bit-range-fixed 31 29 0) (bit-range-fixed 28 27 1) (bit-range-fixed 14 12 3) (bit-range-fixed 6 2 11) (bit-range-fixed 1 0 3)))
(define amoadd.d (make-instruction rd rs1 rs2 aq rl (bit-range-fixed 31 29 0) (bit-range-fixed 28 27 0) (bit-range-fixed 14 12 3) (bit-range-fixed 6 2 11) (bit-range-fixed 1 0 3)))
(define amoxor.d (make-instruction rd rs1 rs2 aq rl (bit-range-fixed 31 29 1) (bit-range-fixed 28 27 0) (bit-range-fixed 14 12 3) (bit-range-fixed 6 2 11) (bit-range-fixed 1 0 3)))
(define amoand.d (make-instruction rd rs1 rs2 aq rl (bit-range-fixed 31 29 3) (bit-range-fixed 28 27 0) (bit-range-fixed 14 12 3) (bit-range-fixed 6 2 11) (bit-range-fixed 1 0 3)))
(define amoor.d (make-instruction rd rs1 rs2 aq rl (bit-range-fixed 31 29 2) (bit-range-fixed 28 27 0) (bit-range-fixed 14 12 3) (bit-range-fixed 6 2 11) (bit-range-fixed 1 0 3)))
(define amomin.d (make-instruction rd rs1 rs2 aq rl (bit-range-fixed 31 29 4) (bit-range-fixed 28 27 0) (bit-range-fixed 14 12 3) (bit-range-fixed 6 2 11) (bit-range-fixed 1 0 3)))
(define amomax.d (make-instruction rd rs1 rs2 aq rl (bit-range-fixed 31 29 5) (bit-range-fixed 28 27 0) (bit-range-fixed 14 12 3) (bit-range-fixed 6 2 11) (bit-range-fixed 1 0 3)))
(define amominu.d (make-instruction rd rs1 rs2 aq rl (bit-range-fixed 31 29 6) (bit-range-fixed 28 27 0) (bit-range-fixed 14 12 3) (bit-range-fixed 6 2 11) (bit-range-fixed 1 0 3)))
(define amomaxu.d (make-instruction rd rs1 rs2 aq rl (bit-range-fixed 31 29 7) (bit-range-fixed 28 27 0) (bit-range-fixed 14 12 3) (bit-range-fixed 6 2 11) (bit-range-fixed 1 0 3)))

(provide (all-defined-out))
