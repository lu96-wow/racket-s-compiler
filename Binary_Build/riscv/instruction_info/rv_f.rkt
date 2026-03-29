#lang racket

(define rv_f-rd
  (make-immutable-hash
    '(
      (flw . 1)
      (fmadd.s . 1)
      (fmsub.s . 1)
      (fnmsub.s . 1)
      (fnmadd.s . 1)
      (fadd.s . 1)
      (fsub.s . 1)
      (fmul.s . 1)
      (fdiv.s . 1)
      (fsqrt.s . 1)
      (fsgnj.s . 1)
      (fsgnjn.s . 1)
      (fsgnjx.s . 1)
      (fmin.s . 1)
      (fmax.s . 1)
      (fcvt.w.s . 1)
      (fcvt.wu.s . 1)
      (fmv.x.w . 1)
      (feq.s . 1)
      (flt.s . 1)
      (fle.s . 1)
      (fclass.s . 1)
      (fcvt.s.w . 1)
      (fcvt.s.wu . 1)
      (fmv.w.x . 1)
    )))
(define rv_f-rs1
  (make-immutable-hash
    '(
      (flw . 2)
      (fsw . 2)
      (fmadd.s . 2)
      (fmsub.s . 2)
      (fnmsub.s . 2)
      (fnmadd.s . 2)
      (fadd.s . 2)
      (fsub.s . 2)
      (fmul.s . 2)
      (fdiv.s . 2)
      (fsqrt.s . 2)
      (fsgnj.s . 2)
      (fsgnjn.s . 2)
      (fsgnjx.s . 2)
      (fmin.s . 2)
      (fmax.s . 2)
      (fcvt.w.s . 2)
      (fcvt.wu.s . 2)
      (fmv.x.w . 2)
      (feq.s . 2)
      (flt.s . 2)
      (fle.s . 2)
      (fclass.s . 2)
      (fcvt.s.w . 2)
      (fcvt.s.wu . 2)
      (fmv.w.x . 2)
    )))
(define rv_f-imm12
  (make-immutable-hash
    '(
      (flw . 3)
      (fsw . 1)
    )))
(define rv_f-rs2
  (make-immutable-hash
    '(
      (fsw . 3)
      (fmadd.s . 3)
      (fmsub.s . 3)
      (fnmsub.s . 3)
      (fnmadd.s . 3)
      (fadd.s . 3)
      (fsub.s . 3)
      (fmul.s . 3)
      (fdiv.s . 3)
      (fsgnj.s . 3)
      (fsgnjn.s . 3)
      (fsgnjx.s . 3)
      (fmin.s . 3)
      (fmax.s . 3)
      (feq.s . 3)
      (flt.s . 3)
      (fle.s . 3)
    )))
(define rv_f-rs3
  (make-immutable-hash
    '(
      (fmadd.s . 4)
      (fmsub.s . 4)
      (fnmsub.s . 4)
      (fnmadd.s . 4)
    )))
(define rv_f-rm
  (make-immutable-hash
    '(
      (fmadd.s . 5)
      (fmsub.s . 5)
      (fnmsub.s . 5)
      (fnmadd.s . 5)
      (fadd.s . 4)
      (fsub.s . 4)
      (fmul.s . 4)
      (fdiv.s . 4)
      (fsqrt.s . 3)
      (fcvt.w.s . 3)
      (fcvt.wu.s . 3)
      (fcvt.s.w . 3)
      (fcvt.s.wu . 3)
    )))

(define rv_f-fields '(rd rs1 imm12 rs2 rs3 rm ))

(provide
  rv_f-rd
  rv_f-rs1
  rv_f-imm12
  rv_f-rs2
  rv_f-rs3
  rv_f-rm
  rv_f-fields)
