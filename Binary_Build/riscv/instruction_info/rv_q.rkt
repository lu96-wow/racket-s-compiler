#lang racket

(define rv_q-rd
  (make-immutable-hash
    '(
      (flq . 1)
      (fmadd.q . 1)
      (fmsub.q . 1)
      (fnmsub.q . 1)
      (fnmadd.q . 1)
      (fadd.q . 1)
      (fsub.q . 1)
      (fmul.q . 1)
      (fdiv.q . 1)
      (fsqrt.q . 1)
      (fsgnj.q . 1)
      (fsgnjn.q . 1)
      (fsgnjx.q . 1)
      (fmin.q . 1)
      (fmax.q . 1)
      (fcvt.s.q . 1)
      (fcvt.q.s . 1)
      (fcvt.d.q . 1)
      (fcvt.q.d . 1)
      (feq.q . 1)
      (flt.q . 1)
      (fle.q . 1)
      (fclass.q . 1)
      (fcvt.w.q . 1)
      (fcvt.wu.q . 1)
      (fcvt.q.w . 1)
      (fcvt.q.wu . 1)
    )))
(define rv_q-rs1
  (make-immutable-hash
    '(
      (flq . 2)
      (fsq . 2)
      (fmadd.q . 2)
      (fmsub.q . 2)
      (fnmsub.q . 2)
      (fnmadd.q . 2)
      (fadd.q . 2)
      (fsub.q . 2)
      (fmul.q . 2)
      (fdiv.q . 2)
      (fsqrt.q . 2)
      (fsgnj.q . 2)
      (fsgnjn.q . 2)
      (fsgnjx.q . 2)
      (fmin.q . 2)
      (fmax.q . 2)
      (fcvt.s.q . 2)
      (fcvt.q.s . 2)
      (fcvt.d.q . 2)
      (fcvt.q.d . 2)
      (feq.q . 2)
      (flt.q . 2)
      (fle.q . 2)
      (fclass.q . 2)
      (fcvt.w.q . 2)
      (fcvt.wu.q . 2)
      (fcvt.q.w . 2)
      (fcvt.q.wu . 2)
    )))
(define rv_q-imm12
  (make-immutable-hash
    '(
      (flq . 3)
      (fsq . 1)
    )))
(define rv_q-rs2
  (make-immutable-hash
    '(
      (fsq . 3)
      (fmadd.q . 3)
      (fmsub.q . 3)
      (fnmsub.q . 3)
      (fnmadd.q . 3)
      (fadd.q . 3)
      (fsub.q . 3)
      (fmul.q . 3)
      (fdiv.q . 3)
      (fsgnj.q . 3)
      (fsgnjn.q . 3)
      (fsgnjx.q . 3)
      (fmin.q . 3)
      (fmax.q . 3)
      (feq.q . 3)
      (flt.q . 3)
      (fle.q . 3)
    )))
(define rv_q-rs3
  (make-immutable-hash
    '(
      (fmadd.q . 4)
      (fmsub.q . 4)
      (fnmsub.q . 4)
      (fnmadd.q . 4)
    )))
(define rv_q-rm
  (make-immutable-hash
    '(
      (fmadd.q . 5)
      (fmsub.q . 5)
      (fnmsub.q . 5)
      (fnmadd.q . 5)
      (fadd.q . 4)
      (fsub.q . 4)
      (fmul.q . 4)
      (fdiv.q . 4)
      (fsqrt.q . 3)
      (fcvt.s.q . 3)
      (fcvt.q.s . 3)
      (fcvt.d.q . 3)
      (fcvt.q.d . 3)
      (fcvt.w.q . 3)
      (fcvt.wu.q . 3)
      (fcvt.q.w . 3)
      (fcvt.q.wu . 3)
    )))

(define rv_q-fields '(rd rs1 imm12 rs2 rs3 rm))

(define rv_q-param-count
  (make-immutable-hash
    '(
      (flq . 3)
      (fsq . 3)
      (fmadd.q . 5)
      (fmsub.q . 5)
      (fnmsub.q . 5)
      (fnmadd.q . 5)
      (fadd.q . 4)
      (fsub.q . 4)
      (fmul.q . 4)
      (fdiv.q . 4)
      (fsqrt.q . 3)
      (fsgnj.q . 3)
      (fsgnjn.q . 3)
      (fsgnjx.q . 3)
      (fmin.q . 3)
      (fmax.q . 3)
      (fcvt.s.q . 3)
      (fcvt.q.s . 3)
      (fcvt.d.q . 3)
      (fcvt.q.d . 3)
      (feq.q . 3)
      (flt.q . 3)
      (fle.q . 3)
      (fclass.q . 2)
      (fcvt.w.q . 3)
      (fcvt.wu.q . 3)
      (fcvt.q.w . 3)
      (fcvt.q.wu . 3)
    )))

(define rv_q-operands
  (make-immutable-hash
    '(
      (flq . (rd rs1 imm12))
      (fsq . (imm12 rs1 rs2))
      (fmadd.q . (rd rs1 rs2 rs3 rm))
      (fmsub.q . (rd rs1 rs2 rs3 rm))
      (fnmsub.q . (rd rs1 rs2 rs3 rm))
      (fnmadd.q . (rd rs1 rs2 rs3 rm))
      (fadd.q . (rd rs1 rs2 rm))
      (fsub.q . (rd rs1 rs2 rm))
      (fmul.q . (rd rs1 rs2 rm))
      (fdiv.q . (rd rs1 rs2 rm))
      (fsqrt.q . (rd rs1 rm))
      (fsgnj.q . (rd rs1 rs2))
      (fsgnjn.q . (rd rs1 rs2))
      (fsgnjx.q . (rd rs1 rs2))
      (fmin.q . (rd rs1 rs2))
      (fmax.q . (rd rs1 rs2))
      (fcvt.s.q . (rd rs1 rm))
      (fcvt.q.s . (rd rs1 rm))
      (fcvt.d.q . (rd rs1 rm))
      (fcvt.q.d . (rd rs1 rm))
      (feq.q . (rd rs1 rs2))
      (flt.q . (rd rs1 rs2))
      (fle.q . (rd rs1 rs2))
      (fclass.q . (rd rs1))
      (fcvt.w.q . (rd rs1 rm))
      (fcvt.wu.q . (rd rs1 rm))
      (fcvt.q.w . (rd rs1 rm))
      (fcvt.q.wu . (rd rs1 rm))
    )))

(define rv_q-asm
  (make-immutable-hash
    '(
      (flq . "flq rd, rs1, imm12")
      (fsq . "fsq imm12, rs1, rs2")
      (fmadd.q . "fmadd.q rd, rs1, rs2, rs3, rm")
      (fmsub.q . "fmsub.q rd, rs1, rs2, rs3, rm")
      (fnmsub.q . "fnmsub.q rd, rs1, rs2, rs3, rm")
      (fnmadd.q . "fnmadd.q rd, rs1, rs2, rs3, rm")
      (fadd.q . "fadd.q rd, rs1, rs2, rm")
      (fsub.q . "fsub.q rd, rs1, rs2, rm")
      (fmul.q . "fmul.q rd, rs1, rs2, rm")
      (fdiv.q . "fdiv.q rd, rs1, rs2, rm")
      (fsqrt.q . "fsqrt.q rd, rs1, rm")
      (fsgnj.q . "fsgnj.q rd, rs1, rs2")
      (fsgnjn.q . "fsgnjn.q rd, rs1, rs2")
      (fsgnjx.q . "fsgnjx.q rd, rs1, rs2")
      (fmin.q . "fmin.q rd, rs1, rs2")
      (fmax.q . "fmax.q rd, rs1, rs2")
      (fcvt.s.q . "fcvt.s.q rd, rs1, rm")
      (fcvt.q.s . "fcvt.q.s rd, rs1, rm")
      (fcvt.d.q . "fcvt.d.q rd, rs1, rm")
      (fcvt.q.d . "fcvt.q.d rd, rs1, rm")
      (feq.q . "feq.q rd, rs1, rs2")
      (flt.q . "flt.q rd, rs1, rs2")
      (fle.q . "fle.q rd, rs1, rs2")
      (fclass.q . "fclass.q rd, rs1")
      (fcvt.w.q . "fcvt.w.q rd, rs1, rm")
      (fcvt.wu.q . "fcvt.wu.q rd, rs1, rm")
      (fcvt.q.w . "fcvt.q.w rd, rs1, rm")
      (fcvt.q.wu . "fcvt.q.wu rd, rs1, rm")
    )))

(define rv_q-operand-types
  (make-immutable-hash
    '(
      (flq . (reg reg imm))
      (fsq . (imm reg reg))
      (fmadd.q . (reg reg reg reg imm))
      (fmsub.q . (reg reg reg reg imm))
      (fnmsub.q . (reg reg reg reg imm))
      (fnmadd.q . (reg reg reg reg imm))
      (fadd.q . (reg reg reg imm))
      (fsub.q . (reg reg reg imm))
      (fmul.q . (reg reg reg imm))
      (fdiv.q . (reg reg reg imm))
      (fsqrt.q . (reg reg imm))
      (fsgnj.q . (reg reg reg))
      (fsgnjn.q . (reg reg reg))
      (fsgnjx.q . (reg reg reg))
      (fmin.q . (reg reg reg))
      (fmax.q . (reg reg reg))
      (fcvt.s.q . (reg reg imm))
      (fcvt.q.s . (reg reg imm))
      (fcvt.d.q . (reg reg imm))
      (fcvt.q.d . (reg reg imm))
      (feq.q . (reg reg reg))
      (flt.q . (reg reg reg))
      (fle.q . (reg reg reg))
      (fclass.q . (reg reg))
      (fcvt.w.q . (reg reg imm))
      (fcvt.wu.q . (reg reg imm))
      (fcvt.q.w . (reg reg imm))
      (fcvt.q.wu . (reg reg imm))
    )))

(define rv_q-width 32)

;; ====== Helper functions ======

(define (rv_q-get-param-count mnemonic)
  (hash-ref rv_q-param-count mnemonic #f))

(define (rv_q-get-operands mnemonic)
  (hash-ref rv_q-operands mnemonic '()))

(define (rv_q-get-asm mnemonic)
  (hash-ref rv_q-asm mnemonic #f))

(define (rv_q-get-operand-types mnemonic)
  (hash-ref rv_q-operand-types mnemonic '()))

(define (rv_q-get-width) rv_q-width)

(define (rv_q-exists? mnemonic)
  (hash-has-key? rv_q-param-count mnemonic))

(define (rv_q-get-field-position mnemonic field)
  (case field
    [(rd) (hash-ref rv_q-rd mnemonic #f)]
    [(rs1) (hash-ref rv_q-rs1 mnemonic #f)]
    [(imm12) (hash-ref rv_q-imm12 mnemonic #f)]
    [(rs2) (hash-ref rv_q-rs2 mnemonic #f)]
    [(rs3) (hash-ref rv_q-rs3 mnemonic #f)]
    [(rm) (hash-ref rv_q-rm mnemonic #f)]
    [else #f]))

(provide
  rv_q-rd
  rv_q-rs1
  rv_q-imm12
  rv_q-rs2
  rv_q-rs3
  rv_q-rm
  rv_q-fields
  rv_q-param-count
  rv_q-operands
  rv_q-asm
  rv_q-operand-types
  rv_q-width
  rv_q-get-param-count
  rv_q-get-operands
  rv_q-get-asm
  rv_q-get-operand-types
  rv_q-get-width
  rv_q-exists?
  rv_q-get-field-position)
