#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define vsm4k.vi (make-instruction 25=1 vs2 zimm5 vd (bit-range-fixed 31 26 33) (bit-range-fixed 14 12 2) (bit-range-fixed 6 0 119)))
(define vsm4r.vv (make-instruction 25=1 vs2 vd (bit-range-fixed 31 26 40) (bit-range-fixed 19 15 16) (bit-range-fixed 14 12 2) (bit-range-fixed 6 0 119)))
(define vsm4r.vs (make-instruction 25=1 vs2 vd (bit-range-fixed 31 26 41) (bit-range-fixed 19 15 16) (bit-range-fixed 14 12 2) (bit-range-fixed 6 0 119)))

(provide (all-defined-out))
