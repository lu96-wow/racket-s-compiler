#lang racket/base

(require "../../../../lib/base.rkt"
         "../../../../lib/riscv/raw/scalar.rkt"
         "../../../../lib/riscv/raw/compressed.rkt"
         "../../../../lib/riscv/raw/vector.rkt"
         "../../../../lib/riscv/raw/mop.rkt")

(define c.ld
  (make-instruction
   (list rd_p_e rs1_p c_uimm8lo c_uimm8hi)
   (list (bit-range-fixed 0 2 0) (bit-range-fixed 13 15 3))))
(define c.sd
  (make-instruction
   (list rs1_p rs2_p_e c_uimm8hi c_uimm8lo)
   (list (bit-range-fixed 0 2 0) (bit-range-fixed 13 15 7))))
(define c.ldsp
  (make-instruction
   (list rd_n0_e c_uimm9sphi c_uimm9splo)
   (list (bit-range-fixed 0 1 2) (bit-range-fixed 13 15 3) (bit-range-fixed 7 7 0))))
(define c.sdsp
  (make-instruction
   (list c_rs2_e c_uimm9sp_s)
   (list (bit-range-fixed 0 2 2) (bit-range-fixed 13 15 7))))

(provide
 c.ld
 c.sd
 c.ldsp
 c.sdsp)
