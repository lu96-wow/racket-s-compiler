#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define amoswap.b (make-instruction rd rs1 rs2 aq rl (bit-range-fixed 31 29 0) (bit-range-fixed 28 27 1) (bit-range-fixed 14 12 0) (bit-range-fixed 6 2 11) (bit-range-fixed 1 0 3)))
(define amoadd.b (make-instruction rd rs1 rs2 aq rl (bit-range-fixed 31 29 0) (bit-range-fixed 28 27 0) (bit-range-fixed 14 12 0) (bit-range-fixed 6 2 11) (bit-range-fixed 1 0 3)))
(define amoxor.b (make-instruction rd rs1 rs2 aq rl (bit-range-fixed 31 29 1) (bit-range-fixed 28 27 0) (bit-range-fixed 14 12 0) (bit-range-fixed 6 2 11) (bit-range-fixed 1 0 3)))
(define amoand.b (make-instruction rd rs1 rs2 aq rl (bit-range-fixed 31 29 3) (bit-range-fixed 28 27 0) (bit-range-fixed 14 12 0) (bit-range-fixed 6 2 11) (bit-range-fixed 1 0 3)))
(define amoor.b (make-instruction rd rs1 rs2 aq rl (bit-range-fixed 31 29 2) (bit-range-fixed 28 27 0) (bit-range-fixed 14 12 0) (bit-range-fixed 6 2 11) (bit-range-fixed 1 0 3)))
(define amomin.b (make-instruction rd rs1 rs2 aq rl (bit-range-fixed 31 29 4) (bit-range-fixed 28 27 0) (bit-range-fixed 14 12 0) (bit-range-fixed 6 2 11) (bit-range-fixed 1 0 3)))
(define amomax.b (make-instruction rd rs1 rs2 aq rl (bit-range-fixed 31 29 5) (bit-range-fixed 28 27 0) (bit-range-fixed 14 12 0) (bit-range-fixed 6 2 11) (bit-range-fixed 1 0 3)))
(define amominu.b (make-instruction rd rs1 rs2 aq rl (bit-range-fixed 31 29 6) (bit-range-fixed 28 27 0) (bit-range-fixed 14 12 0) (bit-range-fixed 6 2 11) (bit-range-fixed 1 0 3)))
(define amomaxu.b (make-instruction rd rs1 rs2 aq rl (bit-range-fixed 31 29 7) (bit-range-fixed 28 27 0) (bit-range-fixed 14 12 0) (bit-range-fixed 6 2 11) (bit-range-fixed 1 0 3)))
(define amoswap.h (make-instruction rd rs1 rs2 aq rl (bit-range-fixed 31 29 0) (bit-range-fixed 28 27 1) (bit-range-fixed 14 12 1) (bit-range-fixed 6 2 11) (bit-range-fixed 1 0 3)))
(define amoadd.h (make-instruction rd rs1 rs2 aq rl (bit-range-fixed 31 29 0) (bit-range-fixed 28 27 0) (bit-range-fixed 14 12 1) (bit-range-fixed 6 2 11) (bit-range-fixed 1 0 3)))
(define amoxor.h (make-instruction rd rs1 rs2 aq rl (bit-range-fixed 31 29 1) (bit-range-fixed 28 27 0) (bit-range-fixed 14 12 1) (bit-range-fixed 6 2 11) (bit-range-fixed 1 0 3)))
(define amoand.h (make-instruction rd rs1 rs2 aq rl (bit-range-fixed 31 29 3) (bit-range-fixed 28 27 0) (bit-range-fixed 14 12 1) (bit-range-fixed 6 2 11) (bit-range-fixed 1 0 3)))
(define amoor.h (make-instruction rd rs1 rs2 aq rl (bit-range-fixed 31 29 2) (bit-range-fixed 28 27 0) (bit-range-fixed 14 12 1) (bit-range-fixed 6 2 11) (bit-range-fixed 1 0 3)))
(define amomin.h (make-instruction rd rs1 rs2 aq rl (bit-range-fixed 31 29 4) (bit-range-fixed 28 27 0) (bit-range-fixed 14 12 1) (bit-range-fixed 6 2 11) (bit-range-fixed 1 0 3)))
(define amomax.h (make-instruction rd rs1 rs2 aq rl (bit-range-fixed 31 29 5) (bit-range-fixed 28 27 0) (bit-range-fixed 14 12 1) (bit-range-fixed 6 2 11) (bit-range-fixed 1 0 3)))
(define amominu.h (make-instruction rd rs1 rs2 aq rl (bit-range-fixed 31 29 6) (bit-range-fixed 28 27 0) (bit-range-fixed 14 12 1) (bit-range-fixed 6 2 11) (bit-range-fixed 1 0 3)))
(define amomaxu.h (make-instruction rd rs1 rs2 aq rl (bit-range-fixed 31 29 7) (bit-range-fixed 28 27 0) (bit-range-fixed 14 12 1) (bit-range-fixed 6 2 11) (bit-range-fixed 1 0 3)))

(provide (all-defined-out))
