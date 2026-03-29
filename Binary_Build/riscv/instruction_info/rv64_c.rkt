#lang racket

(define rv64_c-rd_p
  (make-immutable-hash
    '(
      (c.ld . 1)
    )))
(define rv64_c-rs1_p
  (make-immutable-hash
    '(
      (c.ld . 2)
      (c.sd . 1)
    )))
(define rv64_c-c_uimm8
  (make-immutable-hash
    '(
      (c.ld . 3)
      (c.sd . 3)
    )))
(define rv64_c-rs2_p
  (make-immutable-hash
    '(
      (c.sd . 2)
      (c.subw . 2)
      (c.addw . 2)
    )))
(define rv64_c-rd_rs1_n0
  (make-immutable-hash
    '(
      (c.addiw . 1)
      (c.slli . 1)
    )))
(define rv64_c-c_imm6
  (make-immutable-hash
    '(
      (c.addiw . 2)
    )))
(define rv64_c-rd_rs1_p
  (make-immutable-hash
    '(
      (c.srli . 1)
      (c.srai . 1)
      (c.subw . 1)
      (c.addw . 1)
    )))
(define rv64_c-c_nzuimm6
  (make-immutable-hash
    '(
      (c.srli . 2)
      (c.srai . 2)
      (c.slli . 2)
    )))
(define rv64_c-rd_n0
  (make-immutable-hash
    '(
      (c.ldsp . 1)
    )))
(define rv64_c-c_uimm9sp
  (make-immutable-hash
    '(
      (c.ldsp . 2)
    )))
(define rv64_c-c_rs2
  (make-immutable-hash
    '(
      (c.sdsp . 1)
    )))
(define rv64_c-c_uimm9sp_s
  (make-immutable-hash
    '(
      (c.sdsp . 2)
    )))

(define rv64_c-fields '(rd_p rs1_p c_uimm8 rs2_p rd_rs1_n0 c_imm6 rd_rs1_p c_nzuimm6 rd_n0 c_uimm9sp c_rs2 c_uimm9sp_s ))

(provide
  rv64_c-rd_p
  rv64_c-rs1_p
  rv64_c-c_uimm8
  rv64_c-rs2_p
  rv64_c-rd_rs1_n0
  rv64_c-c_imm6
  rv64_c-rd_rs1_p
  rv64_c-c_nzuimm6
  rv64_c-rd_n0
  rv64_c-c_uimm9sp
  rv64_c-c_rs2
  rv64_c-c_uimm9sp_s
  rv64_c-fields)
