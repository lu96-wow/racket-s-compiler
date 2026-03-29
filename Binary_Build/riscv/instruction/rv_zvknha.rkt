#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define vsha2ms.vv (make-instruction 25=1 vs2 vs1 vd (bit-range-fixed 31 26 45) (bit-range-fixed 14 12 2) (bit-range-fixed 6 0 119)))
(define vsha2ch.vv (make-instruction 25=1 vs2 vs1 vd (bit-range-fixed 31 26 46) (bit-range-fixed 14 12 2) (bit-range-fixed 6 0 119)))
(define vsha2cl.vv (make-instruction 25=1 vs2 vs1 vd (bit-range-fixed 31 26 47) (bit-range-fixed 14 12 2) (bit-range-fixed 6 0 119)))

(provide (all-defined-out))
