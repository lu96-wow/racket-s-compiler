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

(define rv_d-fields '(rd rs1 imm12 rs2 rs3 rm ))

(provide
  rv_d-rd
  rv_d-rs1
  rv_d-imm12
  rv_d-rs2
  rv_d-rs3
  rv_d-rm
  rv_d-fields)
