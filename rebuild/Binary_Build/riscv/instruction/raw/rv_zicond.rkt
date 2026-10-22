#lang racket/base

(require "../../../base.rkt"
         "../../raw/scalar.rkt"
         "../../raw/compressed.rkt"
         "../../raw/vector.rkt"
         "../../raw/mop.rkt")

(define czero.eqz
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 25 31 7) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define czero.nez
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 25 31 7) (bit-range-fixed 12 14 7) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))

(provide
 czero.eqz
 czero.nez)
