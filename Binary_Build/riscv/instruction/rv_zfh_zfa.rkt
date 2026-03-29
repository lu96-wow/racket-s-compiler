#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define fli.h (make-instruction rd rs1 (bit-range-fixed 24 20 1) (bit-range-fixed 31 27 30) (bit-range-fixed 14 12 0) (bit-range-fixed 26 25 2) (bit-range-fixed 6 2 20) (bit-range-fixed 1 0 3)))
(define fminm.h (make-instruction rd rs1 rs2 (bit-range-fixed 31 27 5) (bit-range-fixed 14 12 2) (bit-range-fixed 26 25 2) (bit-range-fixed 6 2 20) (bit-range-fixed 1 0 3)))
(define fmaxm.h (make-instruction rd rs1 rs2 (bit-range-fixed 31 27 5) (bit-range-fixed 14 12 3) (bit-range-fixed 26 25 2) (bit-range-fixed 6 2 20) (bit-range-fixed 1 0 3)))
(define fround.h (make-instruction rd rs1 rm (bit-range-fixed 24 20 4) (bit-range-fixed 31 27 8) (bit-range-fixed 26 25 2) (bit-range-fixed 6 2 20) (bit-range-fixed 1 0 3)))
(define froundnx.h (make-instruction rd rs1 rm (bit-range-fixed 24 20 5) (bit-range-fixed 31 27 8) (bit-range-fixed 26 25 2) (bit-range-fixed 6 2 20) (bit-range-fixed 1 0 3)))
(define fleq.h (make-instruction rd rs1 rs2 (bit-range-fixed 31 27 20) (bit-range-fixed 14 12 4) (bit-range-fixed 26 25 2) (bit-range-fixed 6 2 20) (bit-range-fixed 1 0 3)))
(define fltq.h (make-instruction rd rs1 rs2 (bit-range-fixed 31 27 20) (bit-range-fixed 14 12 5) (bit-range-fixed 26 25 2) (bit-range-fixed 6 2 20) (bit-range-fixed 1 0 3)))

(provide (all-defined-out))
