#lang racket
(require "../../base.rkt"
         "../base_range.rkt"
         "../register.rkt")

(define csrrw (make-instruction rd rs1 csr (bit-range-fixed 14 12 1) (bit-range-fixed 6 2 28) (bit-range-fixed 1 0 3)))
(define csrrs (make-instruction rd rs1 csr (bit-range-fixed 14 12 2) (bit-range-fixed 6 2 28) (bit-range-fixed 1 0 3)))
(define csrrc (make-instruction rd rs1 csr (bit-range-fixed 14 12 3) (bit-range-fixed 6 2 28) (bit-range-fixed 1 0 3)))
(define csrrwi (make-instruction rd csr zimm5 (bit-range-fixed 14 12 5) (bit-range-fixed 6 2 28) (bit-range-fixed 1 0 3)))
(define csrrsi (make-instruction rd csr zimm5 (bit-range-fixed 14 12 6) (bit-range-fixed 6 2 28) (bit-range-fixed 1 0 3)))
(define csrrci (make-instruction rd csr zimm5 (bit-range-fixed 14 12 7) (bit-range-fixed 6 2 28) (bit-range-fixed 1 0 3)))

(provide (all-defined-out))
