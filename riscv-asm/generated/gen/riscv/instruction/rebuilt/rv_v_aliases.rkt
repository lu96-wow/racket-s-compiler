#lang racket/base

(require "../../../../lib/base.rkt"
         (prefix-in raw: "../../../../lib/riscv/raw/scalar.rkt")
         (prefix-in raw: "../../../../lib/riscv/raw/compressed.rkt")
         (prefix-in raw: "../../../../lib/riscv/raw/vector.rkt")
         (prefix-in raw: "../../../../lib/riscv/raw/mop.rkt")
         (prefix-in rebuilt: "../../../../lib/riscv/rebuilt/scalar.rkt")
         (prefix-in rebuilt: "../../../../lib/riscv/rebuilt/compressed.rkt")
         (prefix-in rebuilt: "../../../../lib/riscv/rebuilt/vector.rkt")
         (prefix-in rebuilt: "../../../../lib/riscv/rebuilt/mop.rkt"))

(define vl1r.v
  (make-instruction
   (list raw:rs1 raw:vd)
   (list (bit-range-fixed 29 31 0) (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 0) (bit-range-fixed 25 25 1) (bit-range-fixed 20 24 8) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 7))))
(define vl2r.v
  (make-instruction
   (list raw:rs1 raw:vd)
   (list (bit-range-fixed 29 31 1) (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 0) (bit-range-fixed 25 25 1) (bit-range-fixed 20 24 8) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 7))))
(define vl4r.v
  (make-instruction
   (list raw:rs1 raw:vd)
   (list (bit-range-fixed 29 31 3) (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 0) (bit-range-fixed 25 25 1) (bit-range-fixed 20 24 8) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 7))))
(define vl8r.v
  (make-instruction
   (list raw:rs1 raw:vd)
   (list (bit-range-fixed 29 31 7) (bit-range-fixed 28 28 0) (bit-range-fixed 26 27 0) (bit-range-fixed 25 25 1) (bit-range-fixed 20 24 8) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 7))))
(define vle1.v
  (make-instruction
   (list raw:rs1 raw:vd)
   (list (bit-range-fixed 28 31 0) (bit-range-fixed 26 27 0) (bit-range-fixed 25 25 1) (bit-range-fixed 20 24 11) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 7))))
(define vse1.v
  (make-instruction
   (list raw:rs1 raw:vs3)
   (list (bit-range-fixed 28 31 0) (bit-range-fixed 26 27 0) (bit-range-fixed 25 25 1) (bit-range-fixed 20 24 11) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 39))))
(define vfredsum.vs
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 1) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vfwredsum.vs
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 49) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 87))))
(define vpopc.m
  (make-instruction
   (list raw:vm raw:vs2 raw:rd)
   (list (bit-range-fixed 26 31 16) (bit-range-fixed 15 19 16) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vmornot.mm
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 28) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))
(define vmandnot.mm
  (make-instruction
   (list raw:vm raw:vs2 raw:vs1 raw:vd)
   (list (bit-range-fixed 26 31 24) (bit-range-fixed 12 14 2) (bit-range-fixed 0 6 87))))

(provide
 vl1r.v
 vl2r.v
 vl4r.v
 vl8r.v
 vle1.v
 vse1.v
 vfredsum.vs
 vfwredsum.vs
 vpopc.m
 vmornot.mm
 vmandnot.mm)
