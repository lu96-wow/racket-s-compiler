#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define fmadd.h (make-instruction rd rs1 rs2 rs3 rm (bit-range-fixed 26 25 2) (bit-range-fixed 6 2 16) (bit-range-fixed 1 0 3)))
(define fmsub.h (make-instruction rd rs1 rs2 rs3 rm (bit-range-fixed 26 25 2) (bit-range-fixed 6 2 17) (bit-range-fixed 1 0 3)))
(define fnmsub.h (make-instruction rd rs1 rs2 rs3 rm (bit-range-fixed 26 25 2) (bit-range-fixed 6 2 18) (bit-range-fixed 1 0 3)))
(define fnmadd.h (make-instruction rd rs1 rs2 rs3 rm (bit-range-fixed 26 25 2) (bit-range-fixed 6 2 19) (bit-range-fixed 1 0 3)))
(define fadd.h (make-instruction rd rs1 rs2 rm (bit-range-fixed 31 27 0) (bit-range-fixed 26 25 2) (bit-range-fixed 6 2 20) (bit-range-fixed 1 0 3)))
(define fsub.h (make-instruction rd rs1 rs2 rm (bit-range-fixed 31 27 1) (bit-range-fixed 26 25 2) (bit-range-fixed 6 2 20) (bit-range-fixed 1 0 3)))
(define fmul.h (make-instruction rd rs1 rs2 rm (bit-range-fixed 31 27 2) (bit-range-fixed 26 25 2) (bit-range-fixed 6 2 20) (bit-range-fixed 1 0 3)))
(define fdiv.h (make-instruction rd rs1 rs2 rm (bit-range-fixed 31 27 3) (bit-range-fixed 26 25 2) (bit-range-fixed 6 2 20) (bit-range-fixed 1 0 3)))
(define fsqrt.h (make-instruction rd rs1 rm (bit-range-fixed 24 20 0) (bit-range-fixed 31 27 11) (bit-range-fixed 26 25 2) (bit-range-fixed 6 2 20) (bit-range-fixed 1 0 3)))
(define fsgnj.h (make-instruction rd rs1 rs2 (bit-range-fixed 31 27 4) (bit-range-fixed 14 12 0) (bit-range-fixed 26 25 2) (bit-range-fixed 6 2 20) (bit-range-fixed 1 0 3)))
(define fsgnjn.h (make-instruction rd rs1 rs2 (bit-range-fixed 31 27 4) (bit-range-fixed 14 12 1) (bit-range-fixed 26 25 2) (bit-range-fixed 6 2 20) (bit-range-fixed 1 0 3)))
(define fsgnjx.h (make-instruction rd rs1 rs2 (bit-range-fixed 31 27 4) (bit-range-fixed 14 12 2) (bit-range-fixed 26 25 2) (bit-range-fixed 6 2 20) (bit-range-fixed 1 0 3)))
(define fmin.h (make-instruction rd rs1 rs2 (bit-range-fixed 31 27 5) (bit-range-fixed 14 12 0) (bit-range-fixed 26 25 2) (bit-range-fixed 6 2 20) (bit-range-fixed 1 0 3)))
(define fmax.h (make-instruction rd rs1 rs2 (bit-range-fixed 31 27 5) (bit-range-fixed 14 12 1) (bit-range-fixed 26 25 2) (bit-range-fixed 6 2 20) (bit-range-fixed 1 0 3)))
(define feq.h (make-instruction rd rs1 rs2 (bit-range-fixed 31 27 20) (bit-range-fixed 14 12 2) (bit-range-fixed 26 25 2) (bit-range-fixed 6 2 20) (bit-range-fixed 1 0 3)))
(define flt.h (make-instruction rd rs1 rs2 (bit-range-fixed 31 27 20) (bit-range-fixed 14 12 1) (bit-range-fixed 26 25 2) (bit-range-fixed 6 2 20) (bit-range-fixed 1 0 3)))
(define fle.h (make-instruction rd rs1 rs2 (bit-range-fixed 31 27 20) (bit-range-fixed 14 12 0) (bit-range-fixed 26 25 2) (bit-range-fixed 6 2 20) (bit-range-fixed 1 0 3)))
(define fclass.h (make-instruction rd rs1 (bit-range-fixed 24 20 0) (bit-range-fixed 31 27 28) (bit-range-fixed 14 12 1) (bit-range-fixed 26 25 2) (bit-range-fixed 6 2 20) (bit-range-fixed 1 0 3)))
(define fcvt.w.h (make-instruction rd rs1 rm (bit-range-fixed 24 20 0) (bit-range-fixed 31 27 24) (bit-range-fixed 26 25 2) (bit-range-fixed 6 2 20) (bit-range-fixed 1 0 3)))
(define fcvt.wu.h (make-instruction rd rs1 rm (bit-range-fixed 24 20 1) (bit-range-fixed 31 27 24) (bit-range-fixed 26 25 2) (bit-range-fixed 6 2 20) (bit-range-fixed 1 0 3)))
(define fcvt.h.w (make-instruction rd rs1 rm (bit-range-fixed 24 20 0) (bit-range-fixed 31 27 26) (bit-range-fixed 26 25 2) (bit-range-fixed 6 2 20) (bit-range-fixed 1 0 3)))
(define fcvt.h.wu (make-instruction rd rs1 rm (bit-range-fixed 24 20 1) (bit-range-fixed 31 27 26) (bit-range-fixed 26 25 2) (bit-range-fixed 6 2 20) (bit-range-fixed 1 0 3)))

(provide (all-defined-out))
