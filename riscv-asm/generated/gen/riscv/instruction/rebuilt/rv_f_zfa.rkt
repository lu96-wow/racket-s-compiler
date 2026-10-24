#lang racket/base

(require "../../../../lib/base.rkt"
         (prefix-in raw: "../../../../lib/riscv/raw/scalar.rkt")
         (prefix-in raw: "../../../../lib/riscv/raw/compressed.rkt")
         (prefix-in raw: "../../../../lib/riscv/raw/vector.rkt")
         (prefix-in raw: "../../../../lib/riscv/raw/mop.rkt")
         (prefix-in rebuilt: "../../field/rebuilt/scalar.rkt")
         (prefix-in rebuilt: "../../field/rebuilt/compressed.rkt")
         (prefix-in rebuilt: "../../field/rebuilt/vector.rkt")
         (prefix-in rebuilt: "../../field/rebuilt/mop.rkt"))

(define fli.s
  (make-instruction
   (list raw:rd raw:rs1)
   (list (bit-range-fixed 20 24 1) (bit-range-fixed 27 31 30) (bit-range-fixed 12 14 0) (bit-range-fixed 25 26 0) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fminm.s
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 27 31 5) (bit-range-fixed 12 14 2) (bit-range-fixed 25 26 0) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fmaxm.s
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 27 31 5) (bit-range-fixed 12 14 3) (bit-range-fixed 25 26 0) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fround.s
  (make-instruction
   (list raw:rd raw:rs1 raw:rm)
   (list (bit-range-fixed 20 24 4) (bit-range-fixed 27 31 8) (bit-range-fixed 25 26 0) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define froundnx.s
  (make-instruction
   (list raw:rd raw:rs1 raw:rm)
   (list (bit-range-fixed 20 24 5) (bit-range-fixed 27 31 8) (bit-range-fixed 25 26 0) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fleq.s
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 27 31 20) (bit-range-fixed 12 14 4) (bit-range-fixed 25 26 0) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fltq.s
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 27 31 20) (bit-range-fixed 12 14 5) (bit-range-fixed 25 26 0) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))

(provide
 fli.s
 fminm.s
 fmaxm.s
 fround.s
 froundnx.s
 fleq.s
 fltq.s)
