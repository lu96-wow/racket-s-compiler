#lang racket

(define rv_c_d-rd_p
  (make-immutable-hash
    '(
      (c.fld . 1)
    )))
(define rv_c_d-rs1_p
  (make-immutable-hash
    '(
      (c.fld . 2)
      (c.fsd . 1)
    )))
(define rv_c_d-c_uimm8
  (make-immutable-hash
    '(
      (c.fld . 3)
      (c.fsd . 3)
    )))
(define rv_c_d-rs2_p
  (make-immutable-hash
    '(
      (c.fsd . 2)
    )))
(define rv_c_d-rd
  (make-immutable-hash
    '(
      (c.fldsp . 1)
    )))
(define rv_c_d-c_uimm9sp
  (make-immutable-hash
    '(
      (c.fldsp . 2)
    )))
(define rv_c_d-c_rs2
  (make-immutable-hash
    '(
      (c.fsdsp . 1)
    )))
(define rv_c_d-c_uimm9sp_s
  (make-immutable-hash
    '(
      (c.fsdsp . 2)
    )))

(define rv_c_d-fields '(rd_p rs1_p c_uimm8 rs2_p rd c_uimm9sp c_rs2 c_uimm9sp_s ))

(provide
  rv_c_d-rd_p
  rv_c_d-rs1_p
  rv_c_d-c_uimm8
  rv_c_d-rs2_p
  rv_c_d-rd
  rv_c_d-c_uimm9sp
  rv_c_d-c_rs2
  rv_c_d-c_uimm9sp_s
  rv_c_d-fields)
