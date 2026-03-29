#lang racket

(define rv_c-rd_p
  (make-immutable-hash
    '(
      (c.addi4spn . 1)
      (c.lw . 1)
    )))
(define rv_c-c_nzuimm10
  (make-immutable-hash
    '(
      (c.addi4spn . 2)
    )))
(define rv_c-rs1_p
  (make-immutable-hash
    '(
      (c.lw . 2)
      (c.sw . 1)
      (c.beqz . 1)
      (c.bnez . 1)
    )))
(define rv_c-c_uimm7
  (make-immutable-hash
    '(
      (c.lw . 3)
      (c.sw . 3)
    )))
(define rv_c-rs2_p
  (make-immutable-hash
    '(
      (c.sw . 2)
      (c.sub . 2)
      (c.xor . 2)
      (c.or . 2)
      (c.and . 2)
    )))
(define rv_c-c_nzimm6
  (make-immutable-hash
    '(
      (c.nop . 1)
      (c.addi . 2)
    )))
(define rv_c-rd_rs1_n0
  (make-immutable-hash
    '(
      (c.addi . 1)
      (c.add . 1)
    )))
(define rv_c-rd_n0
  (make-immutable-hash
    '(
      (c.li . 1)
      (c.lwsp . 1)
      (c.mv . 1)
    )))
(define rv_c-c_imm6
  (make-immutable-hash
    '(
      (c.li . 2)
      (c.andi . 2)
    )))
(define rv_c-c_nzimm10
  (make-immutable-hash
    '(
      (c.addi16sp . 1)
    )))
(define rv_c-rd_n2
  (make-immutable-hash
    '(
      (c.lui . 1)
    )))
(define rv_c-c_nzimm18
  (make-immutable-hash
    '(
      (c.lui . 2)
    )))
(define rv_c-rd_rs1_p
  (make-immutable-hash
    '(
      (c.andi . 1)
      (c.sub . 1)
      (c.xor . 1)
      (c.or . 1)
      (c.and . 1)
    )))
(define rv_c-c_imm12
  (make-immutable-hash
    '(
      (c.j . 1)
    )))
(define rv_c-c_bimm9
  (make-immutable-hash
    '(
      (c.beqz . 2)
      (c.bnez . 2)
    )))
(define rv_c-c_uimm8sp
  (make-immutable-hash
    '(
      (c.lwsp . 2)
    )))
(define rv_c-rs1_n0
  (make-immutable-hash
    '(
      (c.jr . 1)
    )))
(define rv_c-12=0
  (make-immutable-hash
    '(
      (c.jr . 2)
      (c.mv . 3)
    )))
(define rv_c-c_rs2_n0
  (make-immutable-hash
    '(
      (c.mv . 2)
      (c.add . 2)
    )))
(define rv_c-12=1
  (make-immutable-hash
    '(
      (c.ebreak . 1)
      (c.jalr . 2)
      (c.add . 3)
    )))
(define rv_c-c_rs1_n0
  (make-immutable-hash
    '(
      (c.jalr . 1)
    )))
(define rv_c-c_rs2
  (make-immutable-hash
    '(
      (c.swsp . 1)
    )))
(define rv_c-c_uimm8sp_s
  (make-immutable-hash
    '(
      (c.swsp . 2)
    )))

(define rv_c-fields '(rd_p c_nzuimm10 rs1_p c_uimm7 rs2_p c_nzimm6 rd_rs1_n0 rd_n0 c_imm6 c_nzimm10 rd_n2 c_nzimm18 rd_rs1_p c_imm12 c_bimm9 c_uimm8sp rs1_n0 12=0 c_rs2_n0 12=1 c_rs1_n0 c_rs2 c_uimm8sp_s ))

(provide
  rv_c-rd_p
  rv_c-c_nzuimm10
  rv_c-rs1_p
  rv_c-c_uimm7
  rv_c-rs2_p
  rv_c-c_nzimm6
  rv_c-rd_rs1_n0
  rv_c-rd_n0
  rv_c-c_imm6
  rv_c-c_nzimm10
  rv_c-rd_n2
  rv_c-c_nzimm18
  rv_c-rd_rs1_p
  rv_c-c_imm12
  rv_c-c_bimm9
  rv_c-c_uimm8sp
  rv_c-rs1_n0
  rv_c-12=0
  rv_c-c_rs2_n0
  rv_c-12=1
  rv_c-c_rs1_n0
  rv_c-c_rs2
  rv_c-c_uimm8sp_s
  rv_c-fields)
