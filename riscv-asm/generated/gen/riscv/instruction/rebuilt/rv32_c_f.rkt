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

(define c.flw
  (let ([encode (make-instruction
   (list raw:rd_p raw:rs1_p rebuilt:c_uimm7 rebuilt:c_uimm7)
   (list (bit-range-fixed 0 1 0) (bit-range-fixed 13 15 3)))])
    (lambda (rd_p rs1_p c_uimm7)
      (encode rd_p rs1_p c_uimm7 c_uimm7))))
(define c.fsw
  (let ([encode (make-instruction
   (list raw:rs1_p raw:rs2_p rebuilt:c_uimm7 rebuilt:c_uimm7)
   (list (bit-range-fixed 0 1 0) (bit-range-fixed 13 15 7)))])
    (lambda (rs1_p rs2_p c_uimm7)
      (encode rs1_p rs2_p c_uimm7 c_uimm7))))
(define c.flwsp
  (let ([encode (make-instruction
   (list raw:rd rebuilt:c_uimm8sp rebuilt:c_uimm8sp)
   (list (bit-range-fixed 0 1 2) (bit-range-fixed 13 15 3)))])
    (lambda (rd c_uimm8sp)
      (encode rd c_uimm8sp c_uimm8sp))))
(define c.fswsp
  (make-instruction
   (list raw:c_rs2 raw:c_uimm8sp_s)
   (list (bit-range-fixed 0 1 2) (bit-range-fixed 13 15 7))))

(provide
 c.flw
 c.fsw
 c.flwsp
 c.fswsp)
