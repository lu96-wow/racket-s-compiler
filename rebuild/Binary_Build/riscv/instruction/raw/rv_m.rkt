#lang racket/base

(require "../../../base.rkt"
         "../../raw/scalar.rkt"
         "../../raw/compressed.rkt"
         "../../raw/vector.rkt"
         "../../raw/mop.rkt")

(define mul
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 25 31 1) (bit-range-fixed 12 14 0) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define mulh
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 25 31 1) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define mulhsu
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 25 31 1) (bit-range-fixed 12 14 2) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define mulhu
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 25 31 1) (bit-range-fixed 12 14 3) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define div
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 25 31 1) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define divu
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 25 31 1) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define rem
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 25 31 1) (bit-range-fixed 12 14 6) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define remu
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 25 31 1) (bit-range-fixed 12 14 7) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))

(provide
 mul
 mulh
 mulhsu
 mulhu
 div
 divu
 rem
 remu)
