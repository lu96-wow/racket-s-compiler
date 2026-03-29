#lang racket

(define rv32_c_f-rd_p
  (make-immutable-hash
    '(
      (c.flw . 1)
    )))
(define rv32_c_f-rs1_p
  (make-immutable-hash
    '(
      (c.flw . 2)
      (c.fsw . 1)
    )))
(define rv32_c_f-c_uimm7
  (make-immutable-hash
    '(
      (c.flw . 3)
      (c.fsw . 3)
    )))
(define rv32_c_f-rs2_p
  (make-immutable-hash
    '(
      (c.fsw . 2)
    )))
(define rv32_c_f-rd
  (make-immutable-hash
    '(
      (c.flwsp . 1)
    )))
(define rv32_c_f-c_uimm8sp
  (make-immutable-hash
    '(
      (c.flwsp . 2)
    )))
(define rv32_c_f-c_rs2
  (make-immutable-hash
    '(
      (c.fswsp . 1)
    )))
(define rv32_c_f-c_uimm8sp_s
  (make-immutable-hash
    '(
      (c.fswsp . 2)
    )))

(define rv32_c_f-fields '(rd_p rs1_p c_uimm7 rs2_p rd c_uimm8sp c_rs2 c_uimm8sp_s ))

(provide
  rv32_c_f-rd_p
  rv32_c_f-rs1_p
  rv32_c_f-c_uimm7
  rv32_c_f-rs2_p
  rv32_c_f-rd
  rv32_c_f-c_uimm8sp
  rv32_c_f-c_rs2
  rv32_c_f-c_uimm8sp_s
  rv32_c_f-fields)
