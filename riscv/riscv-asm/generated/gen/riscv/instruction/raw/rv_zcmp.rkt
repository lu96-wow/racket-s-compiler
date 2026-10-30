#lang racket/base

(require "../../../../lib/base.rkt"
         "../../../../lib/riscv/raw/scalar.rkt"
         "../../../../lib/riscv/raw/compressed.rkt"
         "../../../../lib/riscv/raw/vector.rkt"
         "../../../../lib/riscv/raw/mop.rkt")

(define cm.push
  (make-instruction
   (list c_rlist c_spimm)
   (list (bit-range-fixed 0 1 2) (bit-range-fixed 13 15 5) (bit-range-fixed 8 12 24))))
(define cm.pop
  (make-instruction
   (list c_rlist c_spimm)
   (list (bit-range-fixed 0 1 2) (bit-range-fixed 13 15 5) (bit-range-fixed 8 12 26))))
(define cm.popretz
  (make-instruction
   (list c_rlist c_spimm)
   (list (bit-range-fixed 0 1 2) (bit-range-fixed 13 15 5) (bit-range-fixed 8 12 28))))
(define cm.popret
  (make-instruction
   (list c_rlist c_spimm)
   (list (bit-range-fixed 0 1 2) (bit-range-fixed 13 15 5) (bit-range-fixed 8 12 30))))
(define cm.mvsa01
  (make-instruction
   (list c_sreg1 c_sreg2)
   (list (bit-range-fixed 0 1 2) (bit-range-fixed 13 15 5) (bit-range-fixed 10 12 3) (bit-range-fixed 5 6 1))))
(define cm.mva01s
  (make-instruction
   (list c_sreg1 c_sreg2)
   (list (bit-range-fixed 0 1 2) (bit-range-fixed 13 15 5) (bit-range-fixed 10 12 3) (bit-range-fixed 5 6 3))))

(provide
 cm.push
 cm.pop
 cm.popretz
 cm.popret
 cm.mvsa01
 cm.mva01s)
