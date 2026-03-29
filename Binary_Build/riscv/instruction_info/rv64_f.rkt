#lang racket

(define rv64_f-rd
  (make-immutable-hash
    '(
      (fcvt.l.s . 1)
      (fcvt.lu.s . 1)
      (fcvt.s.l . 1)
      (fcvt.s.lu . 1)
    )))
(define rv64_f-rs1
  (make-immutable-hash
    '(
      (fcvt.l.s . 2)
      (fcvt.lu.s . 2)
      (fcvt.s.l . 2)
      (fcvt.s.lu . 2)
    )))
(define rv64_f-rm
  (make-immutable-hash
    '(
      (fcvt.l.s . 3)
      (fcvt.lu.s . 3)
      (fcvt.s.l . 3)
      (fcvt.s.lu . 3)
    )))

(define rv64_f-fields '(rd rs1 rm ))

(provide
  rv64_f-rd
  rv64_f-rs1
  rv64_f-rm
  rv64_f-fields)
