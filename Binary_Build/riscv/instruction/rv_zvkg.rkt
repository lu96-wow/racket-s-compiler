#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define vgmul.vv (make-instruction vs2 vd (bit-range-fixed 31 26 40) (bit-range-fixed 25 25 1) (bit-range-fixed 19 15 17) (bit-range-fixed 14 12 2) (bit-range-fixed 6 0 119)))
(define vghsh.vv (make-instruction vs2 vs1 vd (bit-range-fixed 31 26 44) (bit-range-fixed 25 25 1) (bit-range-fixed 14 12 2) (bit-range-fixed 6 0 119)))

(provide (all-defined-out))
