#lang racket/base

(require "../../../base.rkt"
         "../../raw/scalar.rkt"
         "../../raw/compressed.rkt"
         "../../raw/vector.rkt"
         "../../raw/mop.rkt")

(define vsm3c.vi
  (make-instruction
   (list vs2 zimm5 vd)
   (list (bit-range-fixed 26 31 43) (bit-range-fixed 25 25 1) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 119))))
(define vsm3me.vv
  (make-instruction
   (list vs2 vs1 vd)
   (list (bit-range-fixed 26 31 32) (bit-range-fixed 25 25 1) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 119))))

(provide
 vsm3c.vi
 vsm3me.vv)
