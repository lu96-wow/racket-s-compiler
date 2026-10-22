#lang racket/base

(require "../../../base.rkt"
         "../../raw/scalar.rkt"
         "../../raw/compressed.rkt"
         "../../raw/vector.rkt"
         "../../raw/mop.rkt")

(define aes64dsm
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 30 31 0) (bit-range-fixed 25 29 31) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 51))))
(define aes64ds
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 30 31 0) (bit-range-fixed 25 29 29) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 51))))
(define aes64ks1i
  (make-instruction
   (list rd rs1 rnum)
   (list (bit-range-fixed 30 31 0) (bit-range-fixed 25 29 24) (bit-range-fixed 24 24 1) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 19))))
(define aes64im
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 30 31 0) (bit-range-fixed 25 29 24) (bit-range-fixed 20 24 0) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 19))))
(define aes64ks2
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 30 31 1) (bit-range-fixed 25 29 31) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 51))))

(provide
 aes64dsm
 aes64ds
 aes64ks1i
 aes64im
 aes64ks2)
