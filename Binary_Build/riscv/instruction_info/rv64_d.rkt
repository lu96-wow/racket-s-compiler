#lang racket

(define rv64_d-rd
  (make-immutable-hash
    '(
      (fcvt.l.d . 1)
      (fcvt.lu.d . 1)
      (fmv.x.d . 1)
      (fcvt.d.l . 1)
      (fcvt.d.lu . 1)
      (fmv.d.x . 1)
    )))
(define rv64_d-rs1
  (make-immutable-hash
    '(
      (fcvt.l.d . 2)
      (fcvt.lu.d . 2)
      (fmv.x.d . 2)
      (fcvt.d.l . 2)
      (fcvt.d.lu . 2)
      (fmv.d.x . 2)
    )))
(define rv64_d-rm
  (make-immutable-hash
    '(
      (fcvt.l.d . 3)
      (fcvt.lu.d . 3)
      (fcvt.d.l . 3)
      (fcvt.d.lu . 3)
    )))

(define rv64_d-fields '(rd rs1 rm ))

(provide
  rv64_d-rd
  rv64_d-rs1
  rv64_d-rm
  rv64_d-fields)
