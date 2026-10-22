#lang racket/base

(require "../../../base.rkt"
         "../../raw/scalar.rkt"
         "../../raw/compressed.rkt"
         "../../raw/vector.rkt"
         "../../raw/mop.rkt")

(define c.fld
  (make-instruction
   (list rd_p rs1_p c_uimm8lo c_uimm8hi)
   (list (bit-range-fixed 0 1 0) (bit-range-fixed 13 15 1))))
(define c.fsd
  (make-instruction
   (list rs1_p rs2_p c_uimm8lo c_uimm8hi)
   (list (bit-range-fixed 0 1 0) (bit-range-fixed 13 15 5))))
(define c.fldsp
  (make-instruction
   (list rd c_uimm9sphi c_uimm9splo)
   (list (bit-range-fixed 0 1 2) (bit-range-fixed 13 15 1))))
(define c.fsdsp
  (make-instruction
   (list c_rs2 c_uimm9sp_s)
   (list (bit-range-fixed 0 1 2) (bit-range-fixed 13 15 5))))

(provide
 c.fld
 c.fsd
 c.fldsp
 c.fsdsp)
