#lang racket/base

(require "../../../base.rkt"
         "../../raw/scalar.rkt"
         "../../raw/compressed.rkt"
         "../../raw/vector.rkt"
         "../../raw/mop.rkt")

(define lr.d
  (make-instruction
   (list rd rs1 aq rl)
   (list (bit-range-fixed 20 24 0) (bit-range-fixed 29 31 0) (bit-range-fixed 27 28 2) (bit-range-fixed 12 14 3) (bit-range-fixed 2 6 11) (bit-range-fixed 0 1 3))))
(define sc.d
  (make-instruction
   (list rd rs1 rs2 aq rl)
   (list (bit-range-fixed 29 31 0) (bit-range-fixed 27 28 3) (bit-range-fixed 12 14 3) (bit-range-fixed 2 6 11) (bit-range-fixed 0 1 3))))
(define amoswap.d
  (make-instruction
   (list rd rs1 rs2 aq rl)
   (list (bit-range-fixed 29 31 0) (bit-range-fixed 27 28 1) (bit-range-fixed 12 14 3) (bit-range-fixed 2 6 11) (bit-range-fixed 0 1 3))))
(define amoadd.d
  (make-instruction
   (list rd rs1 rs2 aq rl)
   (list (bit-range-fixed 29 31 0) (bit-range-fixed 27 28 0) (bit-range-fixed 12 14 3) (bit-range-fixed 2 6 11) (bit-range-fixed 0 1 3))))
(define amoxor.d
  (make-instruction
   (list rd rs1 rs2 aq rl)
   (list (bit-range-fixed 29 31 1) (bit-range-fixed 27 28 0) (bit-range-fixed 12 14 3) (bit-range-fixed 2 6 11) (bit-range-fixed 0 1 3))))
(define amoand.d
  (make-instruction
   (list rd rs1 rs2 aq rl)
   (list (bit-range-fixed 29 31 3) (bit-range-fixed 27 28 0) (bit-range-fixed 12 14 3) (bit-range-fixed 2 6 11) (bit-range-fixed 0 1 3))))
(define amoor.d
  (make-instruction
   (list rd rs1 rs2 aq rl)
   (list (bit-range-fixed 29 31 2) (bit-range-fixed 27 28 0) (bit-range-fixed 12 14 3) (bit-range-fixed 2 6 11) (bit-range-fixed 0 1 3))))
(define amomin.d
  (make-instruction
   (list rd rs1 rs2 aq rl)
   (list (bit-range-fixed 29 31 4) (bit-range-fixed 27 28 0) (bit-range-fixed 12 14 3) (bit-range-fixed 2 6 11) (bit-range-fixed 0 1 3))))
(define amomax.d
  (make-instruction
   (list rd rs1 rs2 aq rl)
   (list (bit-range-fixed 29 31 5) (bit-range-fixed 27 28 0) (bit-range-fixed 12 14 3) (bit-range-fixed 2 6 11) (bit-range-fixed 0 1 3))))
(define amominu.d
  (make-instruction
   (list rd rs1 rs2 aq rl)
   (list (bit-range-fixed 29 31 6) (bit-range-fixed 27 28 0) (bit-range-fixed 12 14 3) (bit-range-fixed 2 6 11) (bit-range-fixed 0 1 3))))
(define amomaxu.d
  (make-instruction
   (list rd rs1 rs2 aq rl)
   (list (bit-range-fixed 29 31 7) (bit-range-fixed 27 28 0) (bit-range-fixed 12 14 3) (bit-range-fixed 2 6 11) (bit-range-fixed 0 1 3))))

(provide
 lr.d
 sc.d
 amoswap.d
 amoadd.d
 amoxor.d
 amoand.d
 amoor.d
 amomin.d
 amomax.d
 amominu.d
 amomaxu.d)
