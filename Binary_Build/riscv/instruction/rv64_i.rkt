#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define lwu (make-instruction rd rs1 imm12 (bit-range-fixed 14 12 6) (bit-range-fixed 6 2 0) (bit-range-fixed 1 0 3)))
(define ld (make-instruction rd rs1 imm12 (bit-range-fixed 14 12 3) (bit-range-fixed 6 2 0) (bit-range-fixed 1 0 3)))
(define sd (make-instruction imm12 rs1 rs2 (bit-range-fixed 14 12 3) (bit-range-fixed 6 2 8) (bit-range-fixed 1 0 3)))
(define slli (make-instruction rd rs1 shamtd (bit-range-fixed 31 26 0) (bit-range-fixed 14 12 1) (bit-range-fixed 6 2 4) (bit-range-fixed 1 0 3)))
(define srli (make-instruction rd rs1 shamtd (bit-range-fixed 31 26 0) (bit-range-fixed 14 12 5) (bit-range-fixed 6 2 4) (bit-range-fixed 1 0 3)))
(define srai (make-instruction rd rs1 shamtd (bit-range-fixed 31 26 16) (bit-range-fixed 14 12 5) (bit-range-fixed 6 2 4) (bit-range-fixed 1 0 3)))
(define addiw (make-instruction rd rs1 imm12 (bit-range-fixed 14 12 0) (bit-range-fixed 6 2 6) (bit-range-fixed 1 0 3)))
(define slliw (make-instruction rd rs1 shamtw (bit-range-fixed 31 25 0) (bit-range-fixed 14 12 1) (bit-range-fixed 6 2 6) (bit-range-fixed 1 0 3)))
(define srliw (make-instruction rd rs1 shamtw (bit-range-fixed 31 25 0) (bit-range-fixed 14 12 5) (bit-range-fixed 6 2 6) (bit-range-fixed 1 0 3)))
(define sraiw (make-instruction rd rs1 shamtw (bit-range-fixed 31 25 32) (bit-range-fixed 14 12 5) (bit-range-fixed 6 2 6) (bit-range-fixed 1 0 3)))
(define addw (make-instruction rd rs1 rs2 (bit-range-fixed 31 25 0) (bit-range-fixed 14 12 0) (bit-range-fixed 6 2 14) (bit-range-fixed 1 0 3)))
(define subw (make-instruction rd rs1 rs2 (bit-range-fixed 31 25 32) (bit-range-fixed 14 12 0) (bit-range-fixed 6 2 14) (bit-range-fixed 1 0 3)))
(define sllw (make-instruction rd rs1 rs2 (bit-range-fixed 31 25 0) (bit-range-fixed 14 12 1) (bit-range-fixed 6 2 14) (bit-range-fixed 1 0 3)))
(define srlw (make-instruction rd rs1 rs2 (bit-range-fixed 31 25 0) (bit-range-fixed 14 12 5) (bit-range-fixed 6 2 14) (bit-range-fixed 1 0 3)))
(define sraw (make-instruction rd rs1 rs2 (bit-range-fixed 31 25 32) (bit-range-fixed 14 12 5) (bit-range-fixed 6 2 14) (bit-range-fixed 1 0 3)))

(provide (all-defined-out))
