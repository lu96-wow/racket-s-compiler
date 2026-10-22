#lang racket/base

(require "../../../base.rkt"
         "../../raw/scalar.rkt"
         "../../raw/compressed.rkt"
         "../../raw/vector.rkt"
         "../../raw/mop.rkt")

(define rdcycleh
  (make-instruction
   (list rd)
   (list (bit-range-fixed 15 19 0) (bit-range-fixed 20 31 3200) (bit-range-fixed 12 14 2) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define rdtimeh
  (make-instruction
   (list rd)
   (list (bit-range-fixed 15 19 0) (bit-range-fixed 20 31 3201) (bit-range-fixed 12 14 2) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define rdinstreth
  (make-instruction
   (list rd)
   (list (bit-range-fixed 15 19 0) (bit-range-fixed 20 31 3202) (bit-range-fixed 12 14 2) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))

(provide
 rdcycleh
 rdtimeh
 rdinstreth)
