#lang racket

(define rv_zcb-rd_p
  (make-immutable-hash
    '(
      (c.lbu . 1)
      (c.lhu . 1)
      (c.lh . 1)
    )))
(define rv_zcb-rs1_p
  (make-immutable-hash
    '(
      (c.lbu . 2)
      (c.lhu . 2)
      (c.lh . 2)
      (c.sb . 2)
      (c.sh . 2)
    )))
(define rv_zcb-c_uimm2
  (make-immutable-hash
    '(
      (c.lbu . 3)
      (c.sb . 3)
    )))
(define rv_zcb-c_uimm1
  (make-immutable-hash
    '(
      (c.lhu . 3)
      (c.lh . 3)
      (c.sh . 3)
    )))
(define rv_zcb-6=0
  (make-immutable-hash
    '(
      (c.lhu . 4)
      (c.sh . 4)
    )))
(define rv_zcb-6=1
  (make-immutable-hash
    '(
      (c.lh . 4)
    )))
(define rv_zcb-rs2_p
  (make-immutable-hash
    '(
      (c.sb . 1)
      (c.sh . 1)
      (c.mul . 2)
    )))
(define rv_zcb-rd_rs1_p
  (make-immutable-hash
    '(
      (c.zext.b . 1)
      (c.sext.b . 1)
      (c.zext.h . 1)
      (c.sext.h . 1)
      (c.not . 1)
      (c.mul . 1)
    )))

(define rv_zcb-fields '(rd_p rs1_p c_uimm2 c_uimm1 6=0 6=1 rs2_p rd_rs1_p ))

(provide
  rv_zcb-rd_p
  rv_zcb-rs1_p
  rv_zcb-c_uimm2
  rv_zcb-c_uimm1
  rv_zcb-6=0
  rv_zcb-6=1
  rv_zcb-rs2_p
  rv_zcb-rd_rs1_p
  rv_zcb-fields)
