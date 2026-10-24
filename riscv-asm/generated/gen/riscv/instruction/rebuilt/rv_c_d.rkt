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

(define c.fld
  (let ([encode (make-instruction
   (list raw:rd_p raw:rs1_p rebuilt:c_uimm8 rebuilt:c_uimm8)
   (list (bit-range-fixed 0 1 0) (bit-range-fixed 13 15 1)))])
    (lambda (rd_p rs1_p c_uimm8)
      (encode rd_p rs1_p c_uimm8 c_uimm8))))
(define c.fsd
  (let ([encode (make-instruction
   (list raw:rs1_p raw:rs2_p rebuilt:c_uimm8 rebuilt:c_uimm8)
   (list (bit-range-fixed 0 1 0) (bit-range-fixed 13 15 5)))])
    (lambda (rs1_p rs2_p c_uimm8)
      (encode rs1_p rs2_p c_uimm8 c_uimm8))))
(define c.fldsp
  (let ([encode (make-instruction
   (list raw:rd rebuilt:c_uimm9sp rebuilt:c_uimm9sp)
   (list (bit-range-fixed 0 1 2) (bit-range-fixed 13 15 1)))])
    (lambda (rd c_uimm9sp)
      (encode rd c_uimm9sp c_uimm9sp))))
(define c.fsdsp
  (make-instruction
   (list raw:c_rs2 raw:c_uimm9sp_s)
   (list (bit-range-fixed 0 1 2) (bit-range-fixed 13 15 5))))

(provide
 c.fld
 c.fsd
 c.fldsp
 c.fsdsp)
