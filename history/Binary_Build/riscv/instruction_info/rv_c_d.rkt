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

(define rv_c_d-fields '(rd_p rs1_p c_uimm8 rs2_p rd c_uimm9sp c_rs2 c_uimm9sp_s))

(define rv_c_d-param-count
  (make-immutable-hash
    '(
      (c.fld . 3)
      (c.fsd . 3)
      (c.fldsp . 2)
      (c.fsdsp . 2)
    )))

(define rv_c_d-operands
  (make-immutable-hash
    '(
      (c.fld . (rd_p rs1_p c_uimm8))
      (c.fsd . (rs1_p rs2_p c_uimm8))
      (c.fldsp . (rd c_uimm9sp))
      (c.fsdsp . (c_rs2 c_uimm9sp_s))
    )))

(define rv_c_d-asm
  (make-immutable-hash
    '(
      (c.fld . "c.fld rd_p, rs1_p, c_uimm8")
      (c.fsd . "c.fsd rs1_p, rs2_p, c_uimm8")
      (c.fldsp . "c.fldsp rd, c_uimm9sp")
      (c.fsdsp . "c.fsdsp c_rs2, c_uimm9sp_s")
    )))

(define rv_c_d-operand-types
  (make-immutable-hash
    '(
      (c.fld . (reg reg imm))
      (c.fsd . (reg reg imm))
      (c.fldsp . (reg imm))
      (c.fsdsp . (reg imm))
    )))

(define rv_c_d-width 16)

;; ====== Helper functions ======

(define (rv_c_d-get-param-count mnemonic)
  (hash-ref rv_c_d-param-count mnemonic #f))

(define (rv_c_d-get-operands mnemonic)
  (hash-ref rv_c_d-operands mnemonic '()))

(define (rv_c_d-get-asm mnemonic)
  (hash-ref rv_c_d-asm mnemonic #f))

(define (rv_c_d-get-operand-types mnemonic)
  (hash-ref rv_c_d-operand-types mnemonic '()))

(define (rv_c_d-get-width) rv_c_d-width)

(define (rv_c_d-exists? mnemonic)
  (hash-has-key? rv_c_d-param-count mnemonic))

(define (rv_c_d-get-field-position mnemonic field)
  (case field
    [(rd_p) (hash-ref rv_c_d-rd_p mnemonic #f)]
    [(rs1_p) (hash-ref rv_c_d-rs1_p mnemonic #f)]
    [(c_uimm8) (hash-ref rv_c_d-c_uimm8 mnemonic #f)]
    [(rs2_p) (hash-ref rv_c_d-rs2_p mnemonic #f)]
    [(rd) (hash-ref rv_c_d-rd mnemonic #f)]
    [(c_uimm9sp) (hash-ref rv_c_d-c_uimm9sp mnemonic #f)]
    [(c_rs2) (hash-ref rv_c_d-c_rs2 mnemonic #f)]
    [(c_uimm9sp_s) (hash-ref rv_c_d-c_uimm9sp_s mnemonic #f)]
    [else #f]))

(provide
  rv_c_d-rd_p
  rv_c_d-rs1_p
  rv_c_d-c_uimm8
  rv_c_d-rs2_p
  rv_c_d-rd
  rv_c_d-c_uimm9sp
  rv_c_d-c_rs2
  rv_c_d-c_uimm9sp_s
  rv_c_d-fields
  rv_c_d-param-count
  rv_c_d-operands
  rv_c_d-asm
  rv_c_d-operand-types
  rv_c_d-width
  rv_c_d-get-param-count
  rv_c_d-get-operands
  rv_c_d-get-asm
  rv_c_d-get-operand-types
  rv_c_d-get-width
  rv_c_d-exists?
  rv_c_d-get-field-position)
