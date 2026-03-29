#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define cm.push (make-instruction c_rlist c_spimm (bit-range-fixed 1 0 2) (bit-range-fixed 15 13 5) (bit-range-fixed 12 8 24)))
(define cm.pop (make-instruction c_rlist c_spimm (bit-range-fixed 1 0 2) (bit-range-fixed 15 13 5) (bit-range-fixed 12 8 26)))
(define cm.popretz (make-instruction c_rlist c_spimm (bit-range-fixed 1 0 2) (bit-range-fixed 15 13 5) (bit-range-fixed 12 8 28)))
(define cm.popret (make-instruction c_rlist c_spimm (bit-range-fixed 1 0 2) (bit-range-fixed 15 13 5) (bit-range-fixed 12 8 30)))
(define cm.mvsa01 (make-instruction c_sreg1 c_sreg2 (bit-range-fixed 1 0 2) (bit-range-fixed 15 13 5) (bit-range-fixed 12 10 3) (bit-range-fixed 6 5 1)))
(define cm.mva01s (make-instruction c_sreg1 c_sreg2 (bit-range-fixed 1 0 2) (bit-range-fixed 15 13 5) (bit-range-fixed 12 10 3) (bit-range-fixed 6 5 3)))

(provide (all-defined-out))
