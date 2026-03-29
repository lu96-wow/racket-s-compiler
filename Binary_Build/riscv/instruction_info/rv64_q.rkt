#lang racket

(define rv64_q-rd
  (make-immutable-hash
    '(
      (fcvt.l.q . 1)
      (fcvt.lu.q . 1)
      (fcvt.q.l . 1)
      (fcvt.q.lu . 1)
    )))
(define rv64_q-rs1
  (make-immutable-hash
    '(
      (fcvt.l.q . 2)
      (fcvt.lu.q . 2)
      (fcvt.q.l . 2)
      (fcvt.q.lu . 2)
    )))
(define rv64_q-rm
  (make-immutable-hash
    '(
      (fcvt.l.q . 3)
      (fcvt.lu.q . 3)
      (fcvt.q.l . 3)
      (fcvt.q.lu . 3)
    )))

(define rv64_q-fields '(rd rs1 rm ))

(provide
  rv64_q-rd
  rv64_q-rs1
  rv64_q-rm
  rv64_q-fields)
