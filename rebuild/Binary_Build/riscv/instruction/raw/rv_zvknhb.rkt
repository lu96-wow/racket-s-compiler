#lang racket/base

(require "../../../base.rkt"
         "../../raw/scalar.rkt"
         "../../raw/compressed.rkt"
         "../../raw/vector.rkt"
         "../../raw/mop.rkt")

(define vsha2ms.vv
  (make-instruction
   (list vs2 vs1 vd)
   (list (bit-range-fixed 26 31 45) (bit-range-fixed 25 25 1) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 119))))
(define vsha2ch.vv
  (make-instruction
   (list vs2 vs1 vd)
   (list (bit-range-fixed 26 31 46) (bit-range-fixed 25 25 1) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 119))))
(define vsha2cl.vv
  (make-instruction
   (list vs2 vs1 vd)
   (list (bit-range-fixed 26 31 47) (bit-range-fixed 25 25 1) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 119))))

(provide
 vsha2ms.vv
 vsha2ch.vv
 vsha2cl.vv)
