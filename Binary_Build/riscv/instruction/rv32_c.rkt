#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define c.jal (make-instruction c_imm12 (bit-range-fixed 1 0 1) (bit-range-fixed 15 13 1)))

(provide (all-defined-out))
