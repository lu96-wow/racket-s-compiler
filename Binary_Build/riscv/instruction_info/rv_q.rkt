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

(define rv_q-fields '(rd rs1 imm12 rs2 rs3 rm ))

(provide
  rv_q-rd
  rv_q-rs1
  rv_q-imm12
  rv_q-rs2
  rv_q-rs3
  rv_q-rm
  rv_q-fields)
