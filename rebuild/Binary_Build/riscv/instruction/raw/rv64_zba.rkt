#lang racket/base

(require "../../../base.rkt"
         "../../raw/scalar.rkt"
         "../../raw/compressed.rkt"
         "../../raw/vector.rkt"
         "../../raw/mop.rkt")

(define add.uw
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 25 31 4) (bit-range-fixed 12 14 0) (bit-range-fixed 2 6 14) (bit-range-fixed 0 1 3))))
(define sh1add.uw
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 25 31 16) (bit-range-fixed 12 14 2) (bit-range-fixed 2 6 14) (bit-range-fixed 0 1 3))))
(define sh2add.uw
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 25 31 16) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 14) (bit-range-fixed 0 1 3))))
(define sh3add.uw
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 25 31 16) (bit-range-fixed 12 14 6) (bit-range-fixed 2 6 14) (bit-range-fixed 0 1 3))))
(define slli.uw
  (make-instruction
   (list rd rs1 shamtd)
   (list (bit-range-fixed 26 31 2) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 6) (bit-range-fixed 0 1 3))))
(define zext.w
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 25 31 4) (bit-range-fixed 20 24 0) (bit-range-fixed 12 14 0) (bit-range-fixed 2 6 14) (bit-range-fixed 0 1 3))))

(provide
 add.uw
 sh1add.uw
 sh2add.uw
 sh3add.uw
 slli.uw
 zext.w)
