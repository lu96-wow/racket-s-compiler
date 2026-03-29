#lang racket

(define rv_d_zfh-rd
  (make-immutable-hash
    '(
      (fcvt.d.h . 1)
      (fcvt.h.d . 1)
    )))
(define rv_d_zfh-rs1
  (make-immutable-hash
    '(
      (fcvt.d.h . 2)
      (fcvt.h.d . 2)
    )))
(define rv_d_zfh-rm
  (make-immutable-hash
    '(
      (fcvt.d.h . 3)
      (fcvt.h.d . 3)
    )))

(define rv_d_zfh-fields '(rd rs1 rm ))

(provide
  rv_d_zfh-rd
  rv_d_zfh-rs1
  rv_d_zfh-rm
  rv_d_zfh-fields)
