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

(define rv_zcb-fields '(rd_p rs1_p c_uimm2 c_uimm1 rs2_p rd_rs1_p))

(define rv_zcb-param-count
  (make-immutable-hash
    '(
      (c.lbu . 3)
      (c.lhu . 3)
      (c.lh . 3)
      (c.sb . 3)
      (c.sh . 3)
      (c.zext.b . 1)
      (c.sext.b . 1)
      (c.zext.h . 1)
      (c.sext.h . 1)
      (c.not . 1)
      (c.mul . 2)
    )))

(define rv_zcb-operands
  (make-immutable-hash
    '(
      (c.lbu . (rd_p rs1_p c_uimm2))
      (c.lhu . (rd_p rs1_p c_uimm1))
      (c.lh . (rd_p rs1_p c_uimm1))
      (c.sb . (rs2_p rs1_p c_uimm2))
      (c.sh . (rs2_p rs1_p c_uimm1))
      (c.zext.b . (rd_rs1_p))
      (c.sext.b . (rd_rs1_p))
      (c.zext.h . (rd_rs1_p))
      (c.sext.h . (rd_rs1_p))
      (c.not . (rd_rs1_p))
      (c.mul . (rd_rs1_p rs2_p))
    )))

(define rv_zcb-asm
  (make-immutable-hash
    '(
      (c.lbu . "c.lbu rd_p, rs1_p, c_uimm2")
      (c.lhu . "c.lhu rd_p, rs1_p, c_uimm1")
      (c.lh . "c.lh rd_p, rs1_p, c_uimm1")
      (c.sb . "c.sb rs2_p, rs1_p, c_uimm2")
      (c.sh . "c.sh rs2_p, rs1_p, c_uimm1")
      (c.zext.b . "c.zext.b rd_rs1_p")
      (c.sext.b . "c.sext.b rd_rs1_p")
      (c.zext.h . "c.zext.h rd_rs1_p")
      (c.sext.h . "c.sext.h rd_rs1_p")
      (c.not . "c.not rd_rs1_p")
      (c.mul . "c.mul rd_rs1_p, rs2_p")
    )))

(define rv_zcb-operand-types
  (make-immutable-hash
    '(
      (c.lbu . (reg reg imm))
      (c.lhu . (reg reg imm))
      (c.lh . (reg reg imm))
      (c.sb . (reg reg imm))
      (c.sh . (reg reg imm))
      (c.zext.b . (reg))
      (c.sext.b . (reg))
      (c.zext.h . (reg))
      (c.sext.h . (reg))
      (c.not . (reg))
      (c.mul . (reg reg))
    )))

(define rv_zcb-width 16)

;; ====== Helper functions ======

(define (rv_zcb-get-param-count mnemonic)
  (hash-ref rv_zcb-param-count mnemonic #f))

(define (rv_zcb-get-operands mnemonic)
  (hash-ref rv_zcb-operands mnemonic '()))

(define (rv_zcb-get-asm mnemonic)
  (hash-ref rv_zcb-asm mnemonic #f))

(define (rv_zcb-get-operand-types mnemonic)
  (hash-ref rv_zcb-operand-types mnemonic '()))

(define (rv_zcb-get-width) rv_zcb-width)

(define (rv_zcb-exists? mnemonic)
  (hash-has-key? rv_zcb-param-count mnemonic))

(define (rv_zcb-get-field-position mnemonic field)
  (case field
    [(rd_p) (hash-ref rv_zcb-rd_p mnemonic #f)]
    [(rs1_p) (hash-ref rv_zcb-rs1_p mnemonic #f)]
    [(c_uimm2) (hash-ref rv_zcb-c_uimm2 mnemonic #f)]
    [(c_uimm1) (hash-ref rv_zcb-c_uimm1 mnemonic #f)]
    [(rs2_p) (hash-ref rv_zcb-rs2_p mnemonic #f)]
    [(rd_rs1_p) (hash-ref rv_zcb-rd_rs1_p mnemonic #f)]
    [else #f]))

(provide
  rv_zcb-rd_p
  rv_zcb-rs1_p
  rv_zcb-c_uimm2
  rv_zcb-c_uimm1
  rv_zcb-rs2_p
  rv_zcb-rd_rs1_p
  rv_zcb-fields
  rv_zcb-param-count
  rv_zcb-operands
  rv_zcb-asm
  rv_zcb-operand-types
  rv_zcb-width
  rv_zcb-get-param-count
  rv_zcb-get-operands
  rv_zcb-get-asm
  rv_zcb-get-operand-types
  rv_zcb-get-width
  rv_zcb-exists?
  rv_zcb-get-field-position)
