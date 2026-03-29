#lang racket

(define rv_zfhmin-rd
  (make-immutable-hash
    '(
      (flh . 1)
      (fcvt.s.h . 1)
      (fcvt.h.s . 1)
      (fmv.x.h . 1)
      (fmv.h.x . 1)
    )))
(define rv_zfhmin-rs1
  (make-immutable-hash
    '(
      (flh . 2)
      (fsh . 2)
      (fcvt.s.h . 2)
      (fcvt.h.s . 2)
      (fmv.x.h . 2)
      (fmv.h.x . 2)
    )))
(define rv_zfhmin-imm12
  (make-immutable-hash
    '(
      (flh . 3)
      (fsh . 1)
    )))
(define rv_zfhmin-rs2
  (make-immutable-hash
    '(
      (fsh . 3)
    )))
(define rv_zfhmin-rm
  (make-immutable-hash
    '(
      (fcvt.s.h . 3)
      (fcvt.h.s . 3)
    )))

(define rv_zfhmin-fields '(rd rs1 imm12 rs2 rm ))

(provide
  rv_zfhmin-rd
  rv_zfhmin-rs1
  rv_zfhmin-imm12
  rv_zfhmin-rs2
  rv_zfhmin-rm
  rv_zfhmin-fields)
