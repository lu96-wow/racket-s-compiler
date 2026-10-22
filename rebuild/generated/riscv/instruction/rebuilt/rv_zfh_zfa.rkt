#lang racket/base

(require "../../../base.rkt"
         (prefix-in raw: "../../raw/scalar.rkt")
         (prefix-in raw: "../../raw/compressed.rkt")
         (prefix-in raw: "../../raw/vector.rkt")
         (prefix-in raw: "../../raw/mop.rkt")
         (prefix-in rebuilt: "../../rebuilt/scalar.rkt")
         (prefix-in rebuilt: "../../rebuilt/compressed.rkt")
         (prefix-in rebuilt: "../../rebuilt/vector.rkt")
         (prefix-in rebuilt: "../../rebuilt/mop.rkt"))

(define fli.h
  (make-instruction
   (list raw:rd raw:rs1)
   (list (bit-range-fixed 20 24 1) (bit-range-fixed 27 31 30) (bit-range-fixed 12 14 0) (bit-range-fixed 25 26 2) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fminm.h
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 27 31 5) (bit-range-fixed 12 14 2) (bit-range-fixed 25 26 2) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fmaxm.h
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 27 31 5) (bit-range-fixed 12 14 3) (bit-range-fixed 25 26 2) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fround.h
  (make-instruction
   (list raw:rd raw:rs1 raw:rm)
   (list (bit-range-fixed 20 24 4) (bit-range-fixed 27 31 8) (bit-range-fixed 25 26 2) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define froundnx.h
  (make-instruction
   (list raw:rd raw:rs1 raw:rm)
   (list (bit-range-fixed 20 24 5) (bit-range-fixed 27 31 8) (bit-range-fixed 25 26 2) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fleq.h
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 27 31 20) (bit-range-fixed 12 14 4) (bit-range-fixed 25 26 2) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))
(define fltq.h
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 27 31 20) (bit-range-fixed 12 14 5) (bit-range-fixed 25 26 2) (bit-range-fixed 2 6 20) (bit-range-fixed 0 1 3))))

(provide
 fli.h
 fminm.h
 fmaxm.h
 fround.h
 froundnx.h
 fleq.h
 fltq.h)
