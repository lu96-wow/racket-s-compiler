#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define andn (make-instruction rd rs1 rs2 (bit-range-fixed 31 25 32) (bit-range-fixed 14 12 7) (bit-range-fixed 6 2 12) (bit-range-fixed 1 0 3)))
(define orn (make-instruction rd rs1 rs2 (bit-range-fixed 31 25 32) (bit-range-fixed 14 12 6) (bit-range-fixed 6 2 12) (bit-range-fixed 1 0 3)))
(define xnor (make-instruction rd rs1 rs2 (bit-range-fixed 31 25 32) (bit-range-fixed 14 12 4) (bit-range-fixed 6 2 12) (bit-range-fixed 1 0 3)))
(define clz (make-instruction rd rs1 (bit-range-fixed 31 20 1536) (bit-range-fixed 14 12 1) (bit-range-fixed 6 2 4) (bit-range-fixed 1 0 3)))
(define ctz (make-instruction rd rs1 (bit-range-fixed 31 20 1537) (bit-range-fixed 14 12 1) (bit-range-fixed 6 2 4) (bit-range-fixed 1 0 3)))
(define cpop (make-instruction rd rs1 (bit-range-fixed 31 20 1538) (bit-range-fixed 14 12 1) (bit-range-fixed 6 2 4) (bit-range-fixed 1 0 3)))
(define max (make-instruction rd rs1 rs2 (bit-range-fixed 31 25 5) (bit-range-fixed 14 12 6) (bit-range-fixed 6 2 12) (bit-range-fixed 1 0 3)))
(define maxu (make-instruction rd rs1 rs2 (bit-range-fixed 31 25 5) (bit-range-fixed 14 12 7) (bit-range-fixed 6 2 12) (bit-range-fixed 1 0 3)))
(define min (make-instruction rd rs1 rs2 (bit-range-fixed 31 25 5) (bit-range-fixed 14 12 4) (bit-range-fixed 6 2 12) (bit-range-fixed 1 0 3)))
(define minu (make-instruction rd rs1 rs2 (bit-range-fixed 31 25 5) (bit-range-fixed 14 12 5) (bit-range-fixed 6 2 12) (bit-range-fixed 1 0 3)))
(define sext.b (make-instruction rd rs1 (bit-range-fixed 31 20 1540) (bit-range-fixed 14 12 1) (bit-range-fixed 6 2 4) (bit-range-fixed 1 0 3)))
(define sext.h (make-instruction rd rs1 (bit-range-fixed 31 20 1541) (bit-range-fixed 14 12 1) (bit-range-fixed 6 2 4) (bit-range-fixed 1 0 3)))
(define rol (make-instruction rd rs1 rs2 (bit-range-fixed 31 25 48) (bit-range-fixed 14 12 1) (bit-range-fixed 6 2 12) (bit-range-fixed 1 0 3)))
(define ror (make-instruction rd rs1 rs2 (bit-range-fixed 31 25 48) (bit-range-fixed 14 12 5) (bit-range-fixed 6 2 12) (bit-range-fixed 1 0 3)))
(define orc.b (make-instruction rd rs1 (bit-range-fixed 31 20 647) (bit-range-fixed 14 12 5) (bit-range-fixed 6 0 19)))

(provide (all-defined-out))
