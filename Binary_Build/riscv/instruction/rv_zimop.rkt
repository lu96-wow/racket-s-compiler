#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define mop.r.N (make-instruction mop_r_t_30 mop_r_t_27_26 mop_r_t_21_20 rd rs1 31=1 (bit-range-fixed 29 28 0) (bit-range-fixed 25 22 7) (bit-range-fixed 14 12 4) (bit-range-fixed 6 2 28) (bit-range-fixed 1 0 3)))
(define mop.rr.N (make-instruction mop_rr_t_30 mop_rr_t_27_26 rd rs1 rs2 31=1 25=1 (bit-range-fixed 29 28 0) (bit-range-fixed 14 12 4) (bit-range-fixed 6 2 28) (bit-range-fixed 1 0 3)))

(provide (all-defined-out))
