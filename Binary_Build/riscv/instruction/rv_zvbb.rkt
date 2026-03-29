#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define vandn.vv (make-instruction vm vs2 vs1 vd (bit-range-fixed 31 26 1) (bit-range-fixed 14 12 0) (bit-range-fixed 6 0 87)))
(define vandn.vx (make-instruction vm vs2 rs1 vd (bit-range-fixed 31 26 1) (bit-range-fixed 14 12 4) (bit-range-fixed 6 0 87)))
(define vbrev.v (make-instruction vm vs2 vd (bit-range-fixed 31 26 18) (bit-range-fixed 19 15 10) (bit-range-fixed 14 12 2) (bit-range-fixed 6 0 87)))
(define vbrev8.v (make-instruction vm vs2 vd (bit-range-fixed 31 26 18) (bit-range-fixed 19 15 8) (bit-range-fixed 14 12 2) (bit-range-fixed 6 0 87)))
(define vrev8.v (make-instruction vm vs2 vd (bit-range-fixed 31 26 18) (bit-range-fixed 19 15 9) (bit-range-fixed 14 12 2) (bit-range-fixed 6 0 87)))
(define vclz.v (make-instruction vm vs2 vd (bit-range-fixed 31 26 18) (bit-range-fixed 19 15 12) (bit-range-fixed 14 12 2) (bit-range-fixed 6 0 87)))
(define vctz.v (make-instruction vm vs2 vd (bit-range-fixed 31 26 18) (bit-range-fixed 19 15 13) (bit-range-fixed 14 12 2) (bit-range-fixed 6 0 87)))
(define vcpop.v (make-instruction vm vs2 vd (bit-range-fixed 31 26 18) (bit-range-fixed 19 15 14) (bit-range-fixed 14 12 2) (bit-range-fixed 6 0 87)))
(define vrol.vv (make-instruction vm vs2 vs1 vd (bit-range-fixed 31 26 21) (bit-range-fixed 14 12 0) (bit-range-fixed 6 0 87)))
(define vrol.vx (make-instruction vm vs2 rs1 vd (bit-range-fixed 31 26 21) (bit-range-fixed 14 12 4) (bit-range-fixed 6 0 87)))
(define vror.vv (make-instruction vm vs2 vs1 vd (bit-range-fixed 31 26 20) (bit-range-fixed 14 12 0) (bit-range-fixed 6 0 87)))
(define vror.vx (make-instruction vm vs2 rs1 vd (bit-range-fixed 31 26 20) (bit-range-fixed 14 12 4) (bit-range-fixed 6 0 87)))
(define vror.vi (make-instruction zimm6 vm vs2 vd (bit-range-fixed 31 27 10) (bit-range-fixed 14 12 3) (bit-range-fixed 6 0 87)))
(define vwsll.vv (make-instruction vm vs2 vs1 vd (bit-range-fixed 31 26 53) (bit-range-fixed 14 12 0) (bit-range-fixed 6 0 87)))
(define vwsll.vx (make-instruction vm vs2 rs1 vd (bit-range-fixed 31 26 53) (bit-range-fixed 14 12 4) (bit-range-fixed 6 0 87)))
(define vwsll.vi (make-instruction vm vs2 zimm5 vd (bit-range-fixed 31 26 53) (bit-range-fixed 14 12 3) (bit-range-fixed 6 0 87)))

(provide (all-defined-out))
