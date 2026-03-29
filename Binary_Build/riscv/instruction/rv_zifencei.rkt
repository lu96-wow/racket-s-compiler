#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define fence.i (make-instruction imm12 rs1 rd (bit-range-fixed 14 12 1) (bit-range-fixed 6 2 3) (bit-range-fixed 1 0 3)))

(provide (all-defined-out))
