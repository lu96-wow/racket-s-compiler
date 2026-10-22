#lang racket

(define rv_zfh-rd
  (make-immutable-hash
    '(
      (fmadd.h . 1)
      (fmsub.h . 1)
      (fnmsub.h . 1)
      (fnmadd.h . 1)
      (fadd.h . 1)
      (fsub.h . 1)
      (fmul.h . 1)
      (fdiv.h . 1)
      (fsqrt.h . 1)
      (fsgnj.h . 1)
      (fsgnjn.h . 1)
      (fsgnjx.h . 1)
      (fmin.h . 1)
      (fmax.h . 1)
      (feq.h . 1)
      (flt.h . 1)
      (fle.h . 1)
      (fclass.h . 1)
      (fcvt.w.h . 1)
      (fcvt.wu.h . 1)
      (fcvt.h.w . 1)
      (fcvt.h.wu . 1)
    )))
(define rv_zfh-rs1
  (make-immutable-hash
    '(
      (fmadd.h . 2)
      (fmsub.h . 2)
      (fnmsub.h . 2)
      (fnmadd.h . 2)
      (fadd.h . 2)
      (fsub.h . 2)
      (fmul.h . 2)
      (fdiv.h . 2)
      (fsqrt.h . 2)
      (fsgnj.h . 2)
      (fsgnjn.h . 2)
      (fsgnjx.h . 2)
      (fmin.h . 2)
      (fmax.h . 2)
      (feq.h . 2)
      (flt.h . 2)
      (fle.h . 2)
      (fclass.h . 2)
      (fcvt.w.h . 2)
      (fcvt.wu.h . 2)
      (fcvt.h.w . 2)
      (fcvt.h.wu . 2)
    )))
(define rv_zfh-rs2
  (make-immutable-hash
    '(
      (fmadd.h . 3)
      (fmsub.h . 3)
      (fnmsub.h . 3)
      (fnmadd.h . 3)
      (fadd.h . 3)
      (fsub.h . 3)
      (fmul.h . 3)
      (fdiv.h . 3)
      (fsgnj.h . 3)
      (fsgnjn.h . 3)
      (fsgnjx.h . 3)
      (fmin.h . 3)
      (fmax.h . 3)
      (feq.h . 3)
      (flt.h . 3)
      (fle.h . 3)
    )))
(define rv_zfh-rs3
  (make-immutable-hash
    '(
      (fmadd.h . 4)
      (fmsub.h . 4)
      (fnmsub.h . 4)
      (fnmadd.h . 4)
    )))
(define rv_zfh-rm
  (make-immutable-hash
    '(
      (fmadd.h . 5)
      (fmsub.h . 5)
      (fnmsub.h . 5)
      (fnmadd.h . 5)
      (fadd.h . 4)
      (fsub.h . 4)
      (fmul.h . 4)
      (fdiv.h . 4)
      (fsqrt.h . 3)
      (fcvt.w.h . 3)
      (fcvt.wu.h . 3)
      (fcvt.h.w . 3)
      (fcvt.h.wu . 3)
    )))

(define rv_zfh-fields '(rd rs1 rs2 rs3 rm))

(define rv_zfh-param-count
  (make-immutable-hash
    '(
      (fmadd.h . 5)
      (fmsub.h . 5)
      (fnmsub.h . 5)
      (fnmadd.h . 5)
      (fadd.h . 4)
      (fsub.h . 4)
      (fmul.h . 4)
      (fdiv.h . 4)
      (fsqrt.h . 3)
      (fsgnj.h . 3)
      (fsgnjn.h . 3)
      (fsgnjx.h . 3)
      (fmin.h . 3)
      (fmax.h . 3)
      (feq.h . 3)
      (flt.h . 3)
      (fle.h . 3)
      (fclass.h . 2)
      (fcvt.w.h . 3)
      (fcvt.wu.h . 3)
      (fcvt.h.w . 3)
      (fcvt.h.wu . 3)
    )))

(define rv_zfh-operands
  (make-immutable-hash
    '(
      (fmadd.h . (rd rs1 rs2 rs3 rm))
      (fmsub.h . (rd rs1 rs2 rs3 rm))
      (fnmsub.h . (rd rs1 rs2 rs3 rm))
      (fnmadd.h . (rd rs1 rs2 rs3 rm))
      (fadd.h . (rd rs1 rs2 rm))
      (fsub.h . (rd rs1 rs2 rm))
      (fmul.h . (rd rs1 rs2 rm))
      (fdiv.h . (rd rs1 rs2 rm))
      (fsqrt.h . (rd rs1 rm))
      (fsgnj.h . (rd rs1 rs2))
      (fsgnjn.h . (rd rs1 rs2))
      (fsgnjx.h . (rd rs1 rs2))
      (fmin.h . (rd rs1 rs2))
      (fmax.h . (rd rs1 rs2))
      (feq.h . (rd rs1 rs2))
      (flt.h . (rd rs1 rs2))
      (fle.h . (rd rs1 rs2))
      (fclass.h . (rd rs1))
      (fcvt.w.h . (rd rs1 rm))
      (fcvt.wu.h . (rd rs1 rm))
      (fcvt.h.w . (rd rs1 rm))
      (fcvt.h.wu . (rd rs1 rm))
    )))

(define rv_zfh-asm
  (make-immutable-hash
    '(
      (fmadd.h . "fmadd.h rd, rs1, rs2, rs3, rm")
      (fmsub.h . "fmsub.h rd, rs1, rs2, rs3, rm")
      (fnmsub.h . "fnmsub.h rd, rs1, rs2, rs3, rm")
      (fnmadd.h . "fnmadd.h rd, rs1, rs2, rs3, rm")
      (fadd.h . "fadd.h rd, rs1, rs2, rm")
      (fsub.h . "fsub.h rd, rs1, rs2, rm")
      (fmul.h . "fmul.h rd, rs1, rs2, rm")
      (fdiv.h . "fdiv.h rd, rs1, rs2, rm")
      (fsqrt.h . "fsqrt.h rd, rs1, rm")
      (fsgnj.h . "fsgnj.h rd, rs1, rs2")
      (fsgnjn.h . "fsgnjn.h rd, rs1, rs2")
      (fsgnjx.h . "fsgnjx.h rd, rs1, rs2")
      (fmin.h . "fmin.h rd, rs1, rs2")
      (fmax.h . "fmax.h rd, rs1, rs2")
      (feq.h . "feq.h rd, rs1, rs2")
      (flt.h . "flt.h rd, rs1, rs2")
      (fle.h . "fle.h rd, rs1, rs2")
      (fclass.h . "fclass.h rd, rs1")
      (fcvt.w.h . "fcvt.w.h rd, rs1, rm")
      (fcvt.wu.h . "fcvt.wu.h rd, rs1, rm")
      (fcvt.h.w . "fcvt.h.w rd, rs1, rm")
      (fcvt.h.wu . "fcvt.h.wu rd, rs1, rm")
    )))

(define rv_zfh-operand-types
  (make-immutable-hash
    '(
      (fmadd.h . (reg reg reg reg imm))
      (fmsub.h . (reg reg reg reg imm))
      (fnmsub.h . (reg reg reg reg imm))
      (fnmadd.h . (reg reg reg reg imm))
      (fadd.h . (reg reg reg imm))
      (fsub.h . (reg reg reg imm))
      (fmul.h . (reg reg reg imm))
      (fdiv.h . (reg reg reg imm))
      (fsqrt.h . (reg reg imm))
      (fsgnj.h . (reg reg reg))
      (fsgnjn.h . (reg reg reg))
      (fsgnjx.h . (reg reg reg))
      (fmin.h . (reg reg reg))
      (fmax.h . (reg reg reg))
      (feq.h . (reg reg reg))
      (flt.h . (reg reg reg))
      (fle.h . (reg reg reg))
      (fclass.h . (reg reg))
      (fcvt.w.h . (reg reg imm))
      (fcvt.wu.h . (reg reg imm))
      (fcvt.h.w . (reg reg imm))
      (fcvt.h.wu . (reg reg imm))
    )))

(define rv_zfh-width 32)

;; ====== Helper functions ======

(define (rv_zfh-get-param-count mnemonic)
  (hash-ref rv_zfh-param-count mnemonic #f))

(define (rv_zfh-get-operands mnemonic)
  (hash-ref rv_zfh-operands mnemonic '()))

(define (rv_zfh-get-asm mnemonic)
  (hash-ref rv_zfh-asm mnemonic #f))

(define (rv_zfh-get-operand-types mnemonic)
  (hash-ref rv_zfh-operand-types mnemonic '()))

(define (rv_zfh-get-width) rv_zfh-width)

(define (rv_zfh-exists? mnemonic)
  (hash-has-key? rv_zfh-param-count mnemonic))

(define (rv_zfh-get-field-position mnemonic field)
  (case field
    [(rd) (hash-ref rv_zfh-rd mnemonic #f)]
    [(rs1) (hash-ref rv_zfh-rs1 mnemonic #f)]
    [(rs2) (hash-ref rv_zfh-rs2 mnemonic #f)]
    [(rs3) (hash-ref rv_zfh-rs3 mnemonic #f)]
    [(rm) (hash-ref rv_zfh-rm mnemonic #f)]
    [else #f]))

(provide
  rv_zfh-rd
  rv_zfh-rs1
  rv_zfh-rs2
  rv_zfh-rs3
  rv_zfh-rm
  rv_zfh-fields
  rv_zfh-param-count
  rv_zfh-operands
  rv_zfh-asm
  rv_zfh-operand-types
  rv_zfh-width
  rv_zfh-get-param-count
  rv_zfh-get-operands
  rv_zfh-get-asm
  rv_zfh-get-operand-types
  rv_zfh-get-width
  rv_zfh-exists?
  rv_zfh-get-field-position)
