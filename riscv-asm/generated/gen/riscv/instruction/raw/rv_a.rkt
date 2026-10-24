#lang racket/base

(require "../../../../lib/base.rkt"
         "../../../../lib/riscv/raw/scalar.rkt"
         "../../../../lib/riscv/raw/compressed.rkt"
         "../../../../lib/riscv/raw/vector.rkt"
         "../../../../lib/riscv/raw/mop.rkt")

(define lr.w
  (make-instruction
   (list rd rs1 aq rl)
   (list (bit-range-fixed 20 24 0) (bit-range-fixed 29 31 0) (bit-range-fixed 27 28 2) (bit-range-fixed 12 14 2) (bit-range-fixed 2 6 11) (bit-range-fixed 0 1 3))))
(define sc.w
  (make-instruction
   (list rd rs1 rs2 aq rl)
   (list (bit-range-fixed 29 31 0) (bit-range-fixed 27 28 3) (bit-range-fixed 12 14 2) (bit-range-fixed 2 6 11) (bit-range-fixed 0 1 3))))
(define amoswap.w
  (make-instruction
   (list rd rs1 rs2 aq rl)
   (list (bit-range-fixed 29 31 0) (bit-range-fixed 27 28 1) (bit-range-fixed 12 14 2) (bit-range-fixed 2 6 11) (bit-range-fixed 0 1 3))))
(define amoadd.w
  (make-instruction
   (list rd rs1 rs2 aq rl)
   (list (bit-range-fixed 29 31 0) (bit-range-fixed 27 28 0) (bit-range-fixed 12 14 2) (bit-range-fixed 2 6 11) (bit-range-fixed 0 1 3))))
(define amoxor.w
  (make-instruction
   (list rd rs1 rs2 aq rl)
   (list (bit-range-fixed 29 31 1) (bit-range-fixed 27 28 0) (bit-range-fixed 12 14 2) (bit-range-fixed 2 6 11) (bit-range-fixed 0 1 3))))
(define amoand.w
  (make-instruction
   (list rd rs1 rs2 aq rl)
   (list (bit-range-fixed 29 31 3) (bit-range-fixed 27 28 0) (bit-range-fixed 12 14 2) (bit-range-fixed 2 6 11) (bit-range-fixed 0 1 3))))
(define amoor.w
  (make-instruction
   (list rd rs1 rs2 aq rl)
   (list (bit-range-fixed 29 31 2) (bit-range-fixed 27 28 0) (bit-range-fixed 12 14 2) (bit-range-fixed 2 6 11) (bit-range-fixed 0 1 3))))
(define amomin.w
  (make-instruction
   (list rd rs1 rs2 aq rl)
   (list (bit-range-fixed 29 31 4) (bit-range-fixed 27 28 0) (bit-range-fixed 12 14 2) (bit-range-fixed 2 6 11) (bit-range-fixed 0 1 3))))
(define amomax.w
  (make-instruction
   (list rd rs1 rs2 aq rl)
   (list (bit-range-fixed 29 31 5) (bit-range-fixed 27 28 0) (bit-range-fixed 12 14 2) (bit-range-fixed 2 6 11) (bit-range-fixed 0 1 3))))
(define amominu.w
  (make-instruction
   (list rd rs1 rs2 aq rl)
   (list (bit-range-fixed 29 31 6) (bit-range-fixed 27 28 0) (bit-range-fixed 12 14 2) (bit-range-fixed 2 6 11) (bit-range-fixed 0 1 3))))
(define amomaxu.w
  (make-instruction
   (list rd rs1 rs2 aq rl)
   (list (bit-range-fixed 29 31 7) (bit-range-fixed 27 28 0) (bit-range-fixed 12 14 2) (bit-range-fixed 2 6 11) (bit-range-fixed 0 1 3))))

(provide
 lr.w
 sc.w
 amoswap.w
 amoadd.w
 amoxor.w
 amoand.w
 amoor.w
 amomin.w
 amomax.w
 amominu.w
 amomaxu.w)
