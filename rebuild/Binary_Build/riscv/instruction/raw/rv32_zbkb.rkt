#lang racket/base

(require "../../../base.rkt"
         "../../raw/scalar.rkt"
         "../../raw/compressed.rkt"
         "../../raw/vector.rkt"
         "../../raw/mop.rkt")

(define zip
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 25 31 4) (bit-range-fixed 20 24 15) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define unzip
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 25 31 4) (bit-range-fixed 20 24 15) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define rev8.rv32
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 20 31 1688) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 19))))
(define rori.rv32
  (make-instruction
   (list rd rs1 shamtw)
   (list (bit-range-fixed 25 31 48) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))

(provide
 zip
 unzip
 rev8.rv32
 rori.rv32)
