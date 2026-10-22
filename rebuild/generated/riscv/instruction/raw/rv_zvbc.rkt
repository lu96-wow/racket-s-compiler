#lang racket/base

(require "../../../base.rkt"
         "../../raw/scalar.rkt"
         "../../raw/compressed.rkt"
         "../../raw/vector.rkt"
         "../../raw/mop.rkt")

(define vclmul.vv
  (make-instruction
   (list vm vs2 vs1 vd)
   (list (bit-range-fixed 26 31 12) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vclmul.vx
  (make-instruction
   (list vm vs2 rs1 vd)
   (list (bit-range-fixed 26 31 12) (bit-range-fixed 12 14 6) (bit-range-fixed 0 6 87))))
(define vclmulh.vv
  (make-instruction
   (list vm vs2 vs1 vd)
   (list (bit-range-fixed 26 31 13) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vclmulh.vx
  (make-instruction
   (list vm vs2 rs1 vd)
   (list (bit-range-fixed 26 31 13) (bit-range-fixed 12 14 6) (bit-range-fixed 0 6 87))))

(provide
 vclmul.vv
 vclmul.vx
 vclmulh.vv
 vclmulh.vx)
