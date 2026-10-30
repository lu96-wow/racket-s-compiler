#lang racket/base

(require "../../../../lib/base.rkt"
         "../../../../lib/riscv/raw/scalar.rkt"
         "../../../../lib/riscv/raw/compressed.rkt"
         "../../../../lib/riscv/raw/vector.rkt"
         "../../../../lib/riscv/raw/mop.rkt")

(define c.flw
  (make-instruction
   (list rd_p rs1_p c_uimm7lo c_uimm7hi)
   (list (bit-range-fixed 0 1 0) (bit-range-fixed 13 15 3))))
(define c.fsw
  (make-instruction
   (list rs1_p rs2_p c_uimm7lo c_uimm7hi)
   (list (bit-range-fixed 0 1 0) (bit-range-fixed 13 15 7))))
(define c.flwsp
  (make-instruction
   (list rd c_uimm8sphi c_uimm8splo)
   (list (bit-range-fixed 0 1 2) (bit-range-fixed 13 15 3))))
(define c.fswsp
  (make-instruction
   (list c_rs2 c_uimm8sp_s)
   (list (bit-range-fixed 0 1 2) (bit-range-fixed 13 15 7))))

(provide
 c.flw
 c.fsw
 c.flwsp
 c.fswsp)
