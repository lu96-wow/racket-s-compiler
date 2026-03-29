#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define vfncvtbf16.f.f.w (make-instruction vm vs2 vd (bit-range-fixed 31 26 18) (bit-range-fixed 19 15 29) (bit-range-fixed 14 12 1) (bit-range-fixed 6 0 87)))
(define vfwcvtbf16.f.f.v (make-instruction vm vs2 vd (bit-range-fixed 31 26 18) (bit-range-fixed 19 15 13) (bit-range-fixed 14 12 1) (bit-range-fixed 6 0 87)))

(provide (all-defined-out))
