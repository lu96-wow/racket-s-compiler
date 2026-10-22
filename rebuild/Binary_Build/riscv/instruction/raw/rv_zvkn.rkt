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
(define vbrev8.v
  (make-instruction
   (list vm vs2 vd)
   (list (bit-range-fixed 26 31 18) (bit-range-fixed 15 19 8) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vrev8.v
  (make-instruction
   (list vm vs2 vd)
   (list (bit-range-fixed 26 31 18) (bit-range-fixed 15 19 9) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
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
(define vaesef.vs
  (make-instruction
   (list vs2 vd)
   (list (bit-range-fixed 26 31 41) (bit-range-fixed 25 25 1) (bit-range-fixed 15 19 3) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 119))))
(define vaesef.vv
  (make-instruction
   (list vs2 vd)
   (list (bit-range-fixed 26 31 40) (bit-range-fixed 25 25 1) (bit-range-fixed 15 19 3) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 119))))
(define vaesem.vs
  (make-instruction
   (list vs2 vd)
   (list (bit-range-fixed 26 31 41) (bit-range-fixed 25 25 1) (bit-range-fixed 15 19 2) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 119))))
(define vaesem.vv
  (make-instruction
   (list vs2 vd)
   (list (bit-range-fixed 26 31 40) (bit-range-fixed 25 25 1) (bit-range-fixed 15 19 2) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 119))))
(define vaesdf.vs
  (make-instruction
   (list vs2 vd)
   (list (bit-range-fixed 26 31 41) (bit-range-fixed 25 25 1) (bit-range-fixed 15 19 1) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 119))))
(define vaesdf.vv
  (make-instruction
   (list vs2 vd)
   (list (bit-range-fixed 26 31 40) (bit-range-fixed 25 25 1) (bit-range-fixed 15 19 1) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 119))))
(define vaesdm.vs
  (make-instruction
   (list vs2 vd)
   (list (bit-range-fixed 26 31 41) (bit-range-fixed 25 25 1) (bit-range-fixed 15 19 0) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 119))))
(define vaesdm.vv
  (make-instruction
   (list vs2 vd)
   (list (bit-range-fixed 26 31 40) (bit-range-fixed 25 25 1) (bit-range-fixed 15 19 0) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 119))))
(define vaeskf1.vi
  (make-instruction
   (list vs2 zimm5 vd)
   (list (bit-range-fixed 26 31 34) (bit-range-fixed 25 25 1) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 119))))
(define vaeskf2.vi
  (make-instruction
   (list vs2 zimm5 vd)
   (list (bit-range-fixed 26 31 42) (bit-range-fixed 25 25 1) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 119))))
(define vaesz.vs
  (make-instruction
   (list vs2 vd)
   (list (bit-range-fixed 26 31 41) (bit-range-fixed 25 25 1) (bit-range-fixed 15 19 7) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 119))))
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
 vandn.vv
 vandn.vx
 vbrev8.v
 vrev8.v
 vrol.vv
 vrol.vx
 vror.vv
 vror.vx
 vror.vi
 vaesef.vs
 vaesef.vv
 vaesem.vs
 vaesem.vv
 vaesdf.vs
 vaesdf.vv
 vaesdm.vs
 vaesdm.vv
 vaeskf1.vi
 vaeskf2.vi
 vaesz.vs
 vsha2ms.vv
 vsha2ch.vv
 vsha2cl.vv)
