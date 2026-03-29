#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define vaesdf.vv (make-instruction vs2 vd (bit-range-fixed 31 26 40) (bit-range-fixed 25 25 1) (bit-range-fixed 19 15 1) (bit-range-fixed 14 12 2) (bit-range-fixed 6 0 119)))
(define vaesdf.vs (make-instruction vs2 vd (bit-range-fixed 31 26 41) (bit-range-fixed 25 25 1) (bit-range-fixed 19 15 1) (bit-range-fixed 14 12 2) (bit-range-fixed 6 0 119)))
(define vaesdm.vv (make-instruction vs2 vd (bit-range-fixed 31 26 40) (bit-range-fixed 25 25 1) (bit-range-fixed 19 15 0) (bit-range-fixed 14 12 2) (bit-range-fixed 6 0 119)))
(define vaesdm.vs (make-instruction vs2 vd (bit-range-fixed 31 26 41) (bit-range-fixed 25 25 1) (bit-range-fixed 19 15 0) (bit-range-fixed 14 12 2) (bit-range-fixed 6 0 119)))
(define vaesef.vv (make-instruction vs2 vd (bit-range-fixed 31 26 40) (bit-range-fixed 25 25 1) (bit-range-fixed 19 15 3) (bit-range-fixed 14 12 2) (bit-range-fixed 6 0 119)))
(define vaesef.vs (make-instruction vs2 vd (bit-range-fixed 31 26 41) (bit-range-fixed 25 25 1) (bit-range-fixed 19 15 3) (bit-range-fixed 14 12 2) (bit-range-fixed 6 0 119)))
(define vaesem.vv (make-instruction vs2 vd (bit-range-fixed 31 26 40) (bit-range-fixed 25 25 1) (bit-range-fixed 19 15 2) (bit-range-fixed 14 12 2) (bit-range-fixed 6 0 119)))
(define vaesem.vs (make-instruction vs2 vd (bit-range-fixed 31 26 41) (bit-range-fixed 25 25 1) (bit-range-fixed 19 15 2) (bit-range-fixed 14 12 2) (bit-range-fixed 6 0 119)))
(define vaesz.vs (make-instruction vs2 vd (bit-range-fixed 31 26 41) (bit-range-fixed 25 25 1) (bit-range-fixed 19 15 7) (bit-range-fixed 14 12 2) (bit-range-fixed 6 0 119)))
(define vaeskf1.vi (make-instruction vs2 zimm5 vd (bit-range-fixed 31 26 34) (bit-range-fixed 25 25 1) (bit-range-fixed 14 12 2) (bit-range-fixed 6 0 119)))
(define vaeskf2.vi (make-instruction vs2 zimm5 vd (bit-range-fixed 31 26 42) (bit-range-fixed 25 25 1) (bit-range-fixed 14 12 2) (bit-range-fixed 6 0 119)))

(provide (all-defined-out))
