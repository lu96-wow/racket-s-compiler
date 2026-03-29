#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define lr.w (make-instruction rd rs1 aq rl (bit-range-fixed 24 20 0) (bit-range-fixed 31 29 0) (bit-range-fixed 28 27 2) (bit-range-fixed 14 12 2) (bit-range-fixed 6 2 11) (bit-range-fixed 1 0 3)))
(define sc.w (make-instruction rd rs1 rs2 aq rl (bit-range-fixed 31 29 0) (bit-range-fixed 28 27 3) (bit-range-fixed 14 12 2) (bit-range-fixed 6 2 11) (bit-range-fixed 1 0 3)))
(define amoswap.w (make-instruction rd rs1 rs2 aq rl (bit-range-fixed 31 29 0) (bit-range-fixed 28 27 1) (bit-range-fixed 14 12 2) (bit-range-fixed 6 2 11) (bit-range-fixed 1 0 3)))
(define amoadd.w (make-instruction rd rs1 rs2 aq rl (bit-range-fixed 31 29 0) (bit-range-fixed 28 27 0) (bit-range-fixed 14 12 2) (bit-range-fixed 6 2 11) (bit-range-fixed 1 0 3)))
(define amoxor.w (make-instruction rd rs1 rs2 aq rl (bit-range-fixed 31 29 1) (bit-range-fixed 28 27 0) (bit-range-fixed 14 12 2) (bit-range-fixed 6 2 11) (bit-range-fixed 1 0 3)))
(define amoand.w (make-instruction rd rs1 rs2 aq rl (bit-range-fixed 31 29 3) (bit-range-fixed 28 27 0) (bit-range-fixed 14 12 2) (bit-range-fixed 6 2 11) (bit-range-fixed 1 0 3)))
(define amoor.w (make-instruction rd rs1 rs2 aq rl (bit-range-fixed 31 29 2) (bit-range-fixed 28 27 0) (bit-range-fixed 14 12 2) (bit-range-fixed 6 2 11) (bit-range-fixed 1 0 3)))
(define amomin.w (make-instruction rd rs1 rs2 aq rl (bit-range-fixed 31 29 4) (bit-range-fixed 28 27 0) (bit-range-fixed 14 12 2) (bit-range-fixed 6 2 11) (bit-range-fixed 1 0 3)))
(define amomax.w (make-instruction rd rs1 rs2 aq rl (bit-range-fixed 31 29 5) (bit-range-fixed 28 27 0) (bit-range-fixed 14 12 2) (bit-range-fixed 6 2 11) (bit-range-fixed 1 0 3)))
(define amominu.w (make-instruction rd rs1 rs2 aq rl (bit-range-fixed 31 29 6) (bit-range-fixed 28 27 0) (bit-range-fixed 14 12 2) (bit-range-fixed 6 2 11) (bit-range-fixed 1 0 3)))
(define amomaxu.w (make-instruction rd rs1 rs2 aq rl (bit-range-fixed 31 29 7) (bit-range-fixed 28 27 0) (bit-range-fixed 14 12 2) (bit-range-fixed 6 2 11) (bit-range-fixed 1 0 3)))

(provide (all-defined-out))
