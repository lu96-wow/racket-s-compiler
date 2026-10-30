#lang racket/base

(require "../../../../lib/base.rkt"
         "../../../../lib/riscv/raw/scalar.rkt"
         "../../../../lib/riscv/raw/compressed.rkt"
         "../../../../lib/riscv/raw/vector.rkt"
         "../../../../lib/riscv/raw/mop.rkt")

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
(define vsm4k.vi
  (make-instruction
   (list vs2 zimm5 vd)
   (list (bit-range-fixed 26 31 33) (bit-range-fixed 25 25 1) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 119))))
(define vsm4r.vv
  (make-instruction
   (list vs2 vd)
   (list (bit-range-fixed 26 31 40) (bit-range-fixed 25 25 1) (bit-range-fixed 15 19 16) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 119))))
(define vsm4r.vs
  (make-instruction
   (list vs2 vd)
   (list (bit-range-fixed 26 31 41) (bit-range-fixed 25 25 1) (bit-range-fixed 15 19 16) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 119))))
(define vsm3c.vi
  (make-instruction
   (list vs2 zimm5 vd)
   (list (bit-range-fixed 26 31 43) (bit-range-fixed 25 25 1) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 119))))
(define vsm3me.vv
  (make-instruction
   (list vs2 vs1 vd)
   (list (bit-range-fixed 26 31 32) (bit-range-fixed 25 25 1) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 119))))

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
 vsm4k.vi
 vsm4r.vv
 vsm4r.vs
 vsm3c.vi
 vsm3me.vv)
