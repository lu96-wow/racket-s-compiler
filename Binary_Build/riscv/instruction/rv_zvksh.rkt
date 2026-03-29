#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define vsm3c.vi (make-instruction 25=1 vs2 zimm5 vd (bit-range-fixed 31 26 43) (bit-range-fixed 14 12 2) (bit-range-fixed 6 0 119)))
(define vsm3me.vv (make-instruction 25=1 vs2 vs1 vd (bit-range-fixed 31 26 32) (bit-range-fixed 14 12 2) (bit-range-fixed 6 0 119)))

(provide (all-defined-out))
