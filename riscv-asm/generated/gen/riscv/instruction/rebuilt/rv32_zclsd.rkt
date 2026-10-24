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

(define c.ld
  (let ([encode (make-instruction
   (list raw:rd_p_e raw:rs1_p rebuilt:c_uimm8 rebuilt:c_uimm8)
   (list (bit-range-fixed 0 2 0) (bit-range-fixed 13 15 3)))])
    (lambda (rd_p_e rs1_p c_uimm8)
      (encode rd_p_e rs1_p c_uimm8 c_uimm8))))
(define c.sd
  (let ([encode (make-instruction
   (list raw:rs1_p raw:rs2_p_e rebuilt:c_uimm8 rebuilt:c_uimm8)
   (list (bit-range-fixed 0 2 0) (bit-range-fixed 13 15 7)))])
    (lambda (rs1_p rs2_p_e c_uimm8)
      (encode rs1_p rs2_p_e c_uimm8 c_uimm8))))
(define c.ldsp
  (let ([encode (make-instruction
   (list raw:rd_n0_e rebuilt:c_uimm9sp rebuilt:c_uimm9sp)
   (list (bit-range-fixed 0 1 2) (bit-range-fixed 13 15 3) (bit-range-fixed 7 7 0)))])
    (lambda (rd_n0_e c_uimm9sp)
      (encode rd_n0_e c_uimm9sp c_uimm9sp))))
(define c.sdsp
  (make-instruction
   (list raw:c_rs2_e raw:c_uimm9sp_s)
   (list (bit-range-fixed 0 2 2) (bit-range-fixed 13 15 7))))

(provide
 c.ld
 c.sd
 c.ldsp
 c.sdsp)
