#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define vfwmaccbf16.vv (make-instruction vm vs2 vs1 vd (bit-range-fixed 31 26 59) (bit-range-fixed 14 12 1) (bit-range-fixed 6 0 87)))
(define vfwmaccbf16.vf (make-instruction vm vs2 rs1 vd (bit-range-fixed 31 26 59) (bit-range-fixed 14 12 5) (bit-range-fixed 6 0 87)))

(provide (all-defined-out))
