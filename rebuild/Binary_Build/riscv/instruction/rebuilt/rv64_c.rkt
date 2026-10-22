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

(define c.ld
  (let ([encode (make-instruction
   (list raw:rd_p raw:rs1_p rebuilt:c_uimm8 rebuilt:c_uimm8)
   (list (bit-range-fixed 0 1 0) (bit-range-fixed 13 15 3)))])
    (lambda (rd_p rs1_p c_uimm8)
      (encode rd_p rs1_p c_uimm8 c_uimm8))))
(define c.sd
  (let ([encode (make-instruction
   (list raw:rs1_p raw:rs2_p rebuilt:c_uimm8 rebuilt:c_uimm8)
   (list (bit-range-fixed 0 1 0) (bit-range-fixed 13 15 7)))])
    (lambda (rs1_p rs2_p c_uimm8)
      (encode rs1_p rs2_p c_uimm8 c_uimm8))))
(define c.addiw
  (let ([encode (make-instruction
   (list raw:rd_rs1_n0 rebuilt:c_imm6 rebuilt:c_imm6)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 1)))])
    (lambda (rd_rs1_n0 c_imm6)
      (encode rd_rs1_n0 c_imm6 c_imm6))))
(define c.srli
  (let ([encode (make-instruction
   (list raw:rd_rs1_p rebuilt:c_nzuimm6 rebuilt:c_nzuimm6)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 4) (bit-range-fixed 10 11 0)))])
    (lambda (rd_rs1_p c_nzuimm6)
      (encode rd_rs1_p c_nzuimm6 c_nzuimm6))))
(define c.srai
  (let ([encode (make-instruction
   (list raw:rd_rs1_p rebuilt:c_nzuimm6 rebuilt:c_nzuimm6)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 4) (bit-range-fixed 10 11 1)))])
    (lambda (rd_rs1_p c_nzuimm6)
      (encode rd_rs1_p c_nzuimm6 c_nzuimm6))))
(define c.subw
  (make-instruction
   (list raw:rd_rs1_p raw:rs2_p)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 4) (bit-range-fixed 10 12 7) (bit-range-fixed 5 6 0))))
(define c.addw
  (make-instruction
   (list raw:rd_rs1_p raw:rs2_p)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 4) (bit-range-fixed 10 12 7) (bit-range-fixed 5 6 1))))
(define c.slli
  (let ([encode (make-instruction
   (list raw:rd_rs1_n0 rebuilt:c_nzuimm6 rebuilt:c_nzuimm6)
   (list (bit-range-fixed 0 1 2) (bit-range-fixed 13 15 0)))])
    (lambda (rd_rs1_n0 c_nzuimm6)
      (encode rd_rs1_n0 c_nzuimm6 c_nzuimm6))))
(define c.ldsp
  (let ([encode (make-instruction
   (list raw:rd_n0 rebuilt:c_uimm9sp rebuilt:c_uimm9sp)
   (list (bit-range-fixed 0 1 2) (bit-range-fixed 13 15 3)))])
    (lambda (rd_n0 c_uimm9sp)
      (encode rd_n0 c_uimm9sp c_uimm9sp))))
(define c.sdsp
  (make-instruction
   (list raw:c_rs2 raw:c_uimm9sp_s)
   (list (bit-range-fixed 0 1 2) (bit-range-fixed 13 15 7))))

(provide
 c.ld
 c.sd
 c.addiw
 c.srli
 c.srai
 c.subw
 c.addw
 c.slli
 c.ldsp
 c.sdsp)
