#lang racket/base

(require "../../../../lib/base.rkt"
         "../../../../lib/riscv/raw/scalar.rkt"
         "../../../../lib/riscv/raw/compressed.rkt"
         "../../../../lib/riscv/raw/vector.rkt"
         "../../../../lib/riscv/raw/mop.rkt")

(define amoswap.b
  (make-instruction
   (list rd rs1 rs2 aq rl)
   (list (bit-range-fixed 29 31 0) (bit-range-fixed 27 28 1) (bit-range-fixed 12 14 0) (bit-range-fixed 2 6 11) (bit-range-fixed 0 1 3))))
(define amoadd.b
  (make-instruction
   (list rd rs1 rs2 aq rl)
   (list (bit-range-fixed 29 31 0) (bit-range-fixed 27 28 0) (bit-range-fixed 12 14 0) (bit-range-fixed 2 6 11) (bit-range-fixed 0 1 3))))
(define amoxor.b
  (make-instruction
   (list rd rs1 rs2 aq rl)
   (list (bit-range-fixed 29 31 1) (bit-range-fixed 27 28 0) (bit-range-fixed 12 14 0) (bit-range-fixed 2 6 11) (bit-range-fixed 0 1 3))))
(define amoand.b
  (make-instruction
   (list rd rs1 rs2 aq rl)
   (list (bit-range-fixed 29 31 3) (bit-range-fixed 27 28 0) (bit-range-fixed 12 14 0) (bit-range-fixed 2 6 11) (bit-range-fixed 0 1 3))))
(define amoor.b
  (make-instruction
   (list rd rs1 rs2 aq rl)
   (list (bit-range-fixed 29 31 2) (bit-range-fixed 27 28 0) (bit-range-fixed 12 14 0) (bit-range-fixed 2 6 11) (bit-range-fixed 0 1 3))))
(define amomin.b
  (make-instruction
   (list rd rs1 rs2 aq rl)
   (list (bit-range-fixed 29 31 4) (bit-range-fixed 27 28 0) (bit-range-fixed 12 14 0) (bit-range-fixed 2 6 11) (bit-range-fixed 0 1 3))))
(define amomax.b
  (make-instruction
   (list rd rs1 rs2 aq rl)
   (list (bit-range-fixed 29 31 5) (bit-range-fixed 27 28 0) (bit-range-fixed 12 14 0) (bit-range-fixed 2 6 11) (bit-range-fixed 0 1 3))))
(define amominu.b
  (make-instruction
   (list rd rs1 rs2 aq rl)
   (list (bit-range-fixed 29 31 6) (bit-range-fixed 27 28 0) (bit-range-fixed 12 14 0) (bit-range-fixed 2 6 11) (bit-range-fixed 0 1 3))))
(define amomaxu.b
  (make-instruction
   (list rd rs1 rs2 aq rl)
   (list (bit-range-fixed 29 31 7) (bit-range-fixed 27 28 0) (bit-range-fixed 12 14 0) (bit-range-fixed 2 6 11) (bit-range-fixed 0 1 3))))
(define amoswap.h
  (make-instruction
   (list rd rs1 rs2 aq rl)
   (list (bit-range-fixed 29 31 0) (bit-range-fixed 27 28 1) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 11) (bit-range-fixed 0 1 3))))
(define amoadd.h
  (make-instruction
   (list rd rs1 rs2 aq rl)
   (list (bit-range-fixed 29 31 0) (bit-range-fixed 27 28 0) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 11) (bit-range-fixed 0 1 3))))
(define amoxor.h
  (make-instruction
   (list rd rs1 rs2 aq rl)
   (list (bit-range-fixed 29 31 1) (bit-range-fixed 27 28 0) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 11) (bit-range-fixed 0 1 3))))
(define amoand.h
  (make-instruction
   (list rd rs1 rs2 aq rl)
   (list (bit-range-fixed 29 31 3) (bit-range-fixed 27 28 0) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 11) (bit-range-fixed 0 1 3))))
(define amoor.h
  (make-instruction
   (list rd rs1 rs2 aq rl)
   (list (bit-range-fixed 29 31 2) (bit-range-fixed 27 28 0) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 11) (bit-range-fixed 0 1 3))))
(define amomin.h
  (make-instruction
   (list rd rs1 rs2 aq rl)
   (list (bit-range-fixed 29 31 4) (bit-range-fixed 27 28 0) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 11) (bit-range-fixed 0 1 3))))
(define amomax.h
  (make-instruction
   (list rd rs1 rs2 aq rl)
   (list (bit-range-fixed 29 31 5) (bit-range-fixed 27 28 0) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 11) (bit-range-fixed 0 1 3))))
(define amominu.h
  (make-instruction
   (list rd rs1 rs2 aq rl)
   (list (bit-range-fixed 29 31 6) (bit-range-fixed 27 28 0) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 11) (bit-range-fixed 0 1 3))))
(define amomaxu.h
  (make-instruction
   (list rd rs1 rs2 aq rl)
   (list (bit-range-fixed 29 31 7) (bit-range-fixed 27 28 0) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 11) (bit-range-fixed 0 1 3))))

(provide
 amoswap.b
 amoadd.b
 amoxor.b
 amoand.b
 amoor.b
 amomin.b
 amomax.b
 amominu.b
 amomaxu.b
 amoswap.h
 amoadd.h
 amoxor.h
 amoand.h
 amoor.h
 amomin.h
 amomax.h
 amominu.h
 amomaxu.h)
