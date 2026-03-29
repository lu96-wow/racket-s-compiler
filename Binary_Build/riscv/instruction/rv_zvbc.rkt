#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define vclmul.vv (make-instruction vm vs2 vs1 vd (bit-range-fixed 31 26 12) (bit-range-fixed 14 12 2) (bit-range-fixed 6 0 87)))
(define vclmul.vx (make-instruction vm vs2 rs1 vd (bit-range-fixed 31 26 12) (bit-range-fixed 14 12 6) (bit-range-fixed 6 0 87)))
(define vclmulh.vv (make-instruction vm vs2 vs1 vd (bit-range-fixed 31 26 13) (bit-range-fixed 14 12 2) (bit-range-fixed 6 0 87)))
(define vclmulh.vx (make-instruction vm vs2 rs1 vd (bit-range-fixed 31 26 13) (bit-range-fixed 14 12 6) (bit-range-fixed 6 0 87)))

(provide (all-defined-out))
