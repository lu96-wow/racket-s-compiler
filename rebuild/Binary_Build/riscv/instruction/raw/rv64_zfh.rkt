#lang racket/base

(require "../../../base.rkt"
         "../../raw/scalar.rkt"
         "../../raw/compressed.rkt"
         "../../raw/vector.rkt"
         "../../raw/mop.rkt")

(define fcvt.l.h
  (make-instruction
   (list rd rs1 rm)
   (list (bit-range-fixed 20 24 2) (bit-range-fixed 27 31 24) (bit-range-fixed 25 26 2) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fcvt.lu.h
  (make-instruction
   (list rd rs1 rm)
   (list (bit-range-fixed 20 24 3) (bit-range-fixed 27 31 24) (bit-range-fixed 25 26 2) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fcvt.h.l
  (make-instruction
   (list rd rs1 rm)
   (list (bit-range-fixed 20 24 2) (bit-range-fixed 27 31 26) (bit-range-fixed 25 26 2) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fcvt.h.lu
  (make-instruction
   (list rd rs1 rm)
   (list (bit-range-fixed 20 24 3) (bit-range-fixed 27 31 26) (bit-range-fixed 25 26 2) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))

(provide
 fcvt.l.h
 fcvt.lu.h
 fcvt.h.l
 fcvt.h.lu)
