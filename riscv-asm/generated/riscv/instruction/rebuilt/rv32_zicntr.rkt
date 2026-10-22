#lang racket/base

(require "../../../base.rkt"
         (prefix-in raw: "../../raw/scalar.rkt")
         (prefix-in raw: "../../raw/compressed.rkt")
         (prefix-in raw: "../../raw/vector.rkt")
         (prefix-in raw: "../../raw/mop.rkt")
         (prefix-in rebuilt: "../../rebuilt/scalar.rkt")
         (prefix-in rebuilt: "../../rebuilt/compressed.rkt")
         (prefix-in rebuilt: "../../rebuilt/vector.rkt")
         (prefix-in rebuilt: "../../rebuilt/mop.rkt"))

(define rdcycleh
  (make-instruction
   (list raw:rd)
   (list (bit-range-fixed 15 19 0) (bit-range-fixed 20 31 3200) (bit-range-fixed 12 14 2) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define rdtimeh
  (make-instruction
   (list raw:rd)
   (list (bit-range-fixed 15 19 0) (bit-range-fixed 20 31 3201) (bit-range-fixed 12 14 2) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define rdinstreth
  (make-instruction
   (list raw:rd)
   (list (bit-range-fixed 15 19 0) (bit-range-fixed 20 31 3202) (bit-range-fixed 12 14 2) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))

(provide
 rdcycleh
 rdtimeh
 rdinstreth)
