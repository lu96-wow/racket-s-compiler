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

(define rv_zfh-fields '(rd rs1 rs2 rs3 rm ))

(provide
  rv_zfh-rd
  rv_zfh-rs1
  rv_zfh-rs2
  rv_zfh-rs3
  rv_zfh-rm
  rv_zfh-fields)
