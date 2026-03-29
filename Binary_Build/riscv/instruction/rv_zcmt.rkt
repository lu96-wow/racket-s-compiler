#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define cm.jalt (make-instruction c_index (bit-range-fixed 1 0 2) (bit-range-fixed 15 13 5) (bit-range-fixed 12 10 0)))

(provide (all-defined-out))
