#lang racket/base

(require "../../../base.rkt"
         "../../raw/scalar.rkt"
         "../../raw/compressed.rkt"
         "../../raw/vector.rkt"
         "../../raw/mop.rkt")

(define vandn.vv
  (make-instruction
   (list vm vs2 vs1 vd)
   (list (bit-range-fixed 26 31 1) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 87))))
(define vandn.vx
  (make-instruction
   (list vm vs2 rs1 vd)
   (list (bit-range-fixed 26 31 1) (bit-range-fixed 12 14 4) (bit-range-fixed 0 6 87))))
(define vbrev.v
  (make-instruction
   (list vm vs2 vd)
   (list (bit-range-fixed 26 31 18) (bit-range-fixed 15 19 10) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vbrev8.v
  (make-instruction
   (list vm vs2 vd)
   (list (bit-range-fixed 26 31 18) (bit-range-fixed 15 19 8) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vrev8.v
  (make-instruction
   (list vm vs2 vd)
   (list (bit-range-fixed 26 31 18) (bit-range-fixed 15 19 9) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vclz.v
  (make-instruction
   (list vm vs2 vd)
   (list (bit-range-fixed 26 31 18) (bit-range-fixed 15 19 12) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vctz.v
  (make-instruction
   (list vm vs2 vd)
   (list (bit-range-fixed 26 31 18) (bit-range-fixed 15 19 13) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vcpop.v
  (make-instruction
   (list vm vs2 vd)
   (list (bit-range-fixed 26 31 18) (bit-range-fixed 15 19 14) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vrol.vv
  (make-instruction
   (list vm vs2 vs1 vd)
   (list (bit-range-fixed 26 31 21) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 87))))
(define vrol.vx
  (make-instruction
   (list vm vs2 rs1 vd)
   (list (bit-range-fixed 26 31 21) (bit-range-fixed 12 14 4) (bit-range-fixed 0 6 87))))
(define vror.vv
  (make-instruction
   (list vm vs2 vs1 vd)
   (list (bit-range-fixed 26 31 20) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 87))))
(define vror.vx
  (make-instruction
   (list vm vs2 rs1 vd)
   (list (bit-range-fixed 26 31 20) (bit-range-fixed 12 14 4) (bit-range-fixed 0 6 87))))
(define vror.vi
  (make-instruction
   (list zimm6hi vm vs2 zimm6lo vd)
   (list (bit-range-fixed 27 31 10) (bit-range-fixed 12 14 3) (bit-range-fixed 0 6 87))))
(define vwsll.vv
  (make-instruction
   (list vm vs2 vs1 vd)
   (list (bit-range-fixed 26 31 53) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 87))))
(define vwsll.vx
  (make-instruction
   (list vm vs2 rs1 vd)
   (list (bit-range-fixed 26 31 53) (bit-range-fixed 12 14 4) (bit-range-fixed 0 6 87))))
(define vwsll.vi
  (make-instruction
   (list vm vs2 zimm5 vd)
   (list (bit-range-fixed 26 31 53) (bit-range-fixed 12 14 3) (bit-range-fixed 0 6 87))))

(provide
 vandn.vv
 vandn.vx
 vbrev.v
 vbrev8.v
 vrev8.v
 vclz.v
 vctz.v
 vcpop.v
 vrol.vv
 vrol.vx
 vror.vv
 vror.vx
 vror.vi
 vwsll.vv
 vwsll.vx
 vwsll.vi)
