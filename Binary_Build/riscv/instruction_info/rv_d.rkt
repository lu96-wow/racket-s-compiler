#lang racket

(define rv_d-rd
  (make-immutable-hash
    '(
      (fld . 1)
      (fmadd.d . 1)
      (fmsub.d . 1)
      (fnmsub.d . 1)
      (fnmadd.d . 1)
      (fadd.d . 1)
      (fsub.d . 1)
      (fmul.d . 1)
      (fdiv.d . 1)
      (fsqrt.d . 1)
      (fsgnj.d . 1)
      (fsgnjn.d . 1)
      (fsgnjx.d . 1)
      (fmin.d . 1)
      (fmax.d . 1)
      (fcvt.s.d . 1)
      (fcvt.d.s . 1)
      (feq.d . 1)
      (flt.d . 1)
      (fle.d . 1)
      (fclass.d . 1)
      (fcvt.w.d . 1)
      (fcvt.wu.d . 1)
      (fcvt.d.w . 1)
      (fcvt.d.wu . 1)
    )))
(define rv_d-rs1
  (make-immutable-hash
    '(
      (fld . 2)
      (fsd . 2)
      (fmadd.d . 2)
      (fmsub.d . 2)
      (fnmsub.d . 2)
      (fnmadd.d . 2)
      (fadd.d . 2)
      (fsub.d . 2)
      (fmul.d . 2)
      (fdiv.d . 2)
      (fsqrt.d . 2)
      (fsgnj.d . 2)
      (fsgnjn.d . 2)
      (fsgnjx.d . 2)
      (fmin.d . 2)
      (fmax.d . 2)
      (fcvt.s.d . 2)
      (fcvt.d.s . 2)
      (feq.d . 2)
      (flt.d . 2)
      (fle.d . 2)
      (fclass.d . 2)
      (fcvt.w.d . 2)
      (fcvt.wu.d . 2)
      (fcvt.d.w . 2)
      (fcvt.d.wu . 2)
    )))
(define rv_d-imm12
  (make-immutable-hash
    '(
      (fld . 3)
    )))
(define rv_d-simm12
  (make-immutable-hash
    '(
      (fsd . 1)
    )))
(define rv_d-rs2
  (make-immutable-hash
    '(
      (fsd . 3)
      (fmadd.d . 3)
      (fmsub.d . 3)
      (fnmsub.d . 3)
      (fnmadd.d . 3)
      (fadd.d . 3)
      (fsub.d . 3)
      (fmul.d . 3)
      (fdiv.d . 3)
      (fsgnj.d . 3)
      (fsgnjn.d . 3)
      (fsgnjx.d . 3)
      (fmin.d . 3)
      (fmax.d . 3)
      (feq.d . 3)
      (flt.d . 3)
      (fle.d . 3)
    )))
(define rv_d-rs3
  (make-immutable-hash
    '(
      (fmadd.d . 4)
      (fmsub.d . 4)
      (fnmsub.d . 4)
      (fnmadd.d . 4)
    )))
(define rv_d-rm
  (make-immutable-hash
    '(
      (fmadd.d . 5)
      (fmsub.d . 5)
      (fnmsub.d . 5)
      (fnmadd.d . 5)
      (fadd.d . 4)
      (fsub.d . 4)
      (fmul.d . 4)
      (fdiv.d . 4)
      (fsqrt.d . 3)
      (fcvt.s.d . 3)
      (fcvt.d.s . 3)
      (fcvt.w.d . 3)
      (fcvt.wu.d . 3)
      (fcvt.d.w . 3)
      (fcvt.d.wu . 3)
    )))

(define rv_d-fields '(rd rs1 imm12 simm12 rs2 rs3 rm))

(define rv_d-param-count
  (make-immutable-hash
    '(
      (fld . 3)
      (fsd . 3)
      (fmadd.d . 5)
      (fmsub.d . 5)
      (fnmsub.d . 5)
      (fnmadd.d . 5)
      (fadd.d . 4)
      (fsub.d . 4)
      (fmul.d . 4)
      (fdiv.d . 4)
      (fsqrt.d . 3)
      (fsgnj.d . 3)
      (fsgnjn.d . 3)
      (fsgnjx.d . 3)
      (fmin.d . 3)
      (fmax.d . 3)
      (fcvt.s.d . 3)
      (fcvt.d.s . 3)
      (feq.d . 3)
      (flt.d . 3)
      (fle.d . 3)
      (fclass.d . 2)
      (fcvt.w.d . 3)
      (fcvt.wu.d . 3)
      (fcvt.d.w . 3)
      (fcvt.d.wu . 3)
    )))

(define rv_d-operands
  (make-immutable-hash
    '(
      (fld . (rd rs1 imm12))
      (fsd . (simm12 rs1 rs2))
      (fmadd.d . (rd rs1 rs2 rs3 rm))
      (fmsub.d . (rd rs1 rs2 rs3 rm))
      (fnmsub.d . (rd rs1 rs2 rs3 rm))
      (fnmadd.d . (rd rs1 rs2 rs3 rm))
      (fadd.d . (rd rs1 rs2 rm))
      (fsub.d . (rd rs1 rs2 rm))
      (fmul.d . (rd rs1 rs2 rm))
      (fdiv.d . (rd rs1 rs2 rm))
      (fsqrt.d . (rd rs1 rm))
      (fsgnj.d . (rd rs1 rs2))
      (fsgnjn.d . (rd rs1 rs2))
      (fsgnjx.d . (rd rs1 rs2))
      (fmin.d . (rd rs1 rs2))
      (fmax.d . (rd rs1 rs2))
      (fcvt.s.d . (rd rs1 rm))
      (fcvt.d.s . (rd rs1 rm))
      (feq.d . (rd rs1 rs2))
      (flt.d . (rd rs1 rs2))
      (fle.d . (rd rs1 rs2))
      (fclass.d . (rd rs1))
      (fcvt.w.d . (rd rs1 rm))
      (fcvt.wu.d . (rd rs1 rm))
      (fcvt.d.w . (rd rs1 rm))
      (fcvt.d.wu . (rd rs1 rm))
    )))

(define rv_d-asm
  (make-immutable-hash
    '(
      (fld . "fld rd, rs1, imm12")
      (fsd . "fsd simm12, rs1, rs2")
      (fmadd.d . "fmadd.d rd, rs1, rs2, rs3, rm")
      (fmsub.d . "fmsub.d rd, rs1, rs2, rs3, rm")
      (fnmsub.d . "fnmsub.d rd, rs1, rs2, rs3, rm")
      (fnmadd.d . "fnmadd.d rd, rs1, rs2, rs3, rm")
      (fadd.d . "fadd.d rd, rs1, rs2, rm")
      (fsub.d . "fsub.d rd, rs1, rs2, rm")
      (fmul.d . "fmul.d rd, rs1, rs2, rm")
      (fdiv.d . "fdiv.d rd, rs1, rs2, rm")
      (fsqrt.d . "fsqrt.d rd, rs1, rm")
      (fsgnj.d . "fsgnj.d rd, rs1, rs2")
      (fsgnjn.d . "fsgnjn.d rd, rs1, rs2")
      (fsgnjx.d . "fsgnjx.d rd, rs1, rs2")
      (fmin.d . "fmin.d rd, rs1, rs2")
      (fmax.d . "fmax.d rd, rs1, rs2")
      (fcvt.s.d . "fcvt.s.d rd, rs1, rm")
      (fcvt.d.s . "fcvt.d.s rd, rs1, rm")
      (feq.d . "feq.d rd, rs1, rs2")
      (flt.d . "flt.d rd, rs1, rs2")
      (fle.d . "fle.d rd, rs1, rs2")
      (fclass.d . "fclass.d rd, rs1")
      (fcvt.w.d . "fcvt.w.d rd, rs1, rm")
      (fcvt.wu.d . "fcvt.wu.d rd, rs1, rm")
      (fcvt.d.w . "fcvt.d.w rd, rs1, rm")
      (fcvt.d.wu . "fcvt.d.wu rd, rs1, rm")
    )))

(define rv_d-operand-types
  (make-immutable-hash
    '(
      (fld . (reg reg imm))
      (fsd . (imm reg reg))
      (fmadd.d . (reg reg reg reg imm))
      (fmsub.d . (reg reg reg reg imm))
      (fnmsub.d . (reg reg reg reg imm))
      (fnmadd.d . (reg reg reg reg imm))
      (fadd.d . (reg reg reg imm))
      (fsub.d . (reg reg reg imm))
      (fmul.d . (reg reg reg imm))
      (fdiv.d . (reg reg reg imm))
      (fsqrt.d . (reg reg imm))
      (fsgnj.d . (reg reg reg))
      (fsgnjn.d . (reg reg reg))
      (fsgnjx.d . (reg reg reg))
      (fmin.d . (reg reg reg))
      (fmax.d . (reg reg reg))
      (fcvt.s.d . (reg reg imm))
      (fcvt.d.s . (reg reg imm))
      (feq.d . (reg reg reg))
      (flt.d . (reg reg reg))
      (fle.d . (reg reg reg))
      (fclass.d . (reg reg))
      (fcvt.w.d . (reg reg imm))
      (fcvt.wu.d . (reg reg imm))
      (fcvt.d.w . (reg reg imm))
      (fcvt.d.wu . (reg reg imm))
    )))

(define rv_d-width 32)

;; ====== Helper functions ======

(define (rv_d-get-param-count mnemonic)
  (hash-ref rv_d-param-count mnemonic #f))

(define (rv_d-get-operands mnemonic)
  (hash-ref rv_d-operands mnemonic '()))

(define (rv_d-get-asm mnemonic)
  (hash-ref rv_d-asm mnemonic #f))

(define (rv_d-get-operand-types mnemonic)
  (hash-ref rv_d-operand-types mnemonic '()))

(define (rv_d-get-width) rv_d-width)

(define (rv_d-exists? mnemonic)
  (hash-has-key? rv_d-param-count mnemonic))

(define (rv_d-get-field-position mnemonic field)
  (case field
    [(rd) (hash-ref rv_d-rd mnemonic #f)]
    [(rs1) (hash-ref rv_d-rs1 mnemonic #f)]
    [(imm12) (hash-ref rv_d-imm12 mnemonic #f)]
    [(simm12) (hash-ref rv_d-simm12 mnemonic #f)]
    [(rs2) (hash-ref rv_d-rs2 mnemonic #f)]
    [(rs3) (hash-ref rv_d-rs3 mnemonic #f)]
    [(rm) (hash-ref rv_d-rm mnemonic #f)]
    [else #f]))

(provide
  rv_d-rd
  rv_d-rs1
  rv_d-imm12
  rv_d-simm12
  rv_d-rs2
  rv_d-rs3
  rv_d-rm
  rv_d-fields
  rv_d-param-count
  rv_d-operands
  rv_d-asm
  rv_d-operand-types
  rv_d-width
  rv_d-get-param-count
  rv_d-get-operands
  rv_d-get-asm
  rv_d-get-operand-types
  rv_d-get-width
  rv_d-exists?
  rv_d-get-field-position)
