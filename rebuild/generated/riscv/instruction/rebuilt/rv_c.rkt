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

(define c.addi4spn
  (make-instruction
   (list raw:rd_p raw:c_nzuimm10)
   (list (bit-range-fixed 0 1 0) (bit-range-fixed 13 15 0))))
(define c.lw
  (let ([encode (make-instruction
   (list raw:rd_p raw:rs1_p rebuilt:c_uimm7 rebuilt:c_uimm7)
   (list (bit-range-fixed 0 1 0) (bit-range-fixed 13 15 2)))])
    (lambda (rd_p rs1_p c_uimm7)
      (encode rd_p rs1_p c_uimm7 c_uimm7))))
(define c.sw
  (let ([encode (make-instruction
   (list raw:rs1_p raw:rs2_p rebuilt:c_uimm7 rebuilt:c_uimm7)
   (list (bit-range-fixed 0 1 0) (bit-range-fixed 13 15 6)))])
    (lambda (rs1_p rs2_p c_uimm7)
      (encode rs1_p rs2_p c_uimm7 c_uimm7))))
(define c.nop
  (let ([encode (make-instruction
   (list rebuilt:c_nzimm6 rebuilt:c_nzimm6)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 0) (bit-range-fixed 7 11 0)))])
    (lambda (c_nzimm6)
      (encode c_nzimm6 c_nzimm6))))
(define c.addi
  (let ([encode (make-instruction
   (list raw:rd_rs1_n0 rebuilt:c_nzimm6 rebuilt:c_nzimm6)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 0)))])
    (lambda (rd_rs1_n0 c_nzimm6)
      (encode rd_rs1_n0 c_nzimm6 c_nzimm6))))
(define c.li
  (let ([encode (make-instruction
   (list raw:rd_n0 rebuilt:c_imm6 rebuilt:c_imm6)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 2)))])
    (lambda (rd_n0 c_imm6)
      (encode rd_n0 c_imm6 c_imm6))))
(define c.addi16sp
  (let ([encode (make-instruction
   (list rebuilt:c_nzimm10 rebuilt:c_nzimm10)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 3) (bit-range-fixed 7 11 2)))])
    (lambda (c_nzimm10)
      (encode c_nzimm10 c_nzimm10))))
(define c.lui
  (let ([encode (make-instruction
   (list raw:rd_n2 rebuilt:c_nzimm18 rebuilt:c_nzimm18)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 3)))])
    (lambda (rd_n2 c_nzimm18)
      (encode rd_n2 c_nzimm18 c_nzimm18))))
(define c.andi
  (let ([encode (make-instruction
   (list raw:rd_rs1_p rebuilt:c_imm6 rebuilt:c_imm6)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 4) (bit-range-fixed 10 11 2)))])
    (lambda (rd_rs1_p c_imm6)
      (encode rd_rs1_p c_imm6 c_imm6))))
(define c.sub
  (make-instruction
   (list raw:rd_rs1_p raw:rs2_p)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 4) (bit-range-fixed 10 12 3) (bit-range-fixed 5 6 0))))
(define c.xor
  (make-instruction
   (list raw:rd_rs1_p raw:rs2_p)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 4) (bit-range-fixed 10 12 3) (bit-range-fixed 5 6 1))))
(define c.or
  (make-instruction
   (list raw:rd_rs1_p raw:rs2_p)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 4) (bit-range-fixed 10 12 3) (bit-range-fixed 5 6 2))))
(define c.and
  (make-instruction
   (list raw:rd_rs1_p raw:rs2_p)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 4) (bit-range-fixed 10 12 3) (bit-range-fixed 5 6 3))))
(define c.j
  (make-instruction
   (list raw:c_imm12)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 5))))
(define c.beqz
  (let ([encode (make-instruction
   (list raw:rs1_p rebuilt:c_bimm9 rebuilt:c_bimm9)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 6)))])
    (lambda (rs1_p c_bimm9)
      (encode rs1_p c_bimm9 c_bimm9))))
(define c.bnez
  (let ([encode (make-instruction
   (list raw:rs1_p rebuilt:c_bimm9 rebuilt:c_bimm9)
   (list (bit-range-fixed 0 1 1) (bit-range-fixed 13 15 7)))])
    (lambda (rs1_p c_bimm9)
      (encode rs1_p c_bimm9 c_bimm9))))
(define c.lwsp
  (let ([encode (make-instruction
   (list raw:rd_n0 rebuilt:c_uimm8sp rebuilt:c_uimm8sp)
   (list (bit-range-fixed 0 1 2) (bit-range-fixed 13 15 2)))])
    (lambda (rd_n0 c_uimm8sp)
      (encode rd_n0 c_uimm8sp c_uimm8sp))))
(define c.jr
  (make-instruction
   (list raw:rs1_n0)
   (list (bit-range-fixed 0 1 2) (bit-range-fixed 13 15 4) (bit-range-fixed 12 12 0) (bit-range-fixed 2 6 0))))
(define c.mv
  (make-instruction
   (list raw:rd_n0 raw:c_rs2_n0)
   (list (bit-range-fixed 0 1 2) (bit-range-fixed 13 15 4) (bit-range-fixed 12 12 0))))
(define c.ebreak
  (make-instruction
   (list)
   (list (bit-range-fixed 0 1 2) (bit-range-fixed 13 15 4) (bit-range-fixed 12 12 1) (bit-range-fixed 2 11 0))))
(define c.jalr
  (make-instruction
   (list raw:c_rs1_n0)
   (list (bit-range-fixed 0 1 2) (bit-range-fixed 13 15 4) (bit-range-fixed 12 12 1) (bit-range-fixed 2 6 0))))
(define c.add
  (make-instruction
   (list raw:rd_rs1_n0 raw:c_rs2_n0)
   (list (bit-range-fixed 0 1 2) (bit-range-fixed 13 15 4) (bit-range-fixed 12 12 1))))
(define c.swsp
  (make-instruction
   (list raw:c_rs2 raw:c_uimm8sp_s)
   (list (bit-range-fixed 0 1 2) (bit-range-fixed 13 15 6))))

(provide
 c.addi4spn
 c.lw
 c.sw
 c.nop
 c.addi
 c.li
 c.addi16sp
 c.lui
 c.andi
 c.sub
 c.xor
 c.or
 c.and
 c.j
 c.beqz
 c.bnez
 c.lwsp
 c.jr
 c.mv
 c.ebreak
 c.jalr
 c.add
 c.swsp)
