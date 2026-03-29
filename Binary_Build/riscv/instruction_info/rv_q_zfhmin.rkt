#lang racket

(define rv_q_zfhmin-rd
  (make-immutable-hash
    '(
      (fcvt.q.h . 1)
      (fcvt.h.q . 1)
    )))
(define rv_q_zfhmin-rs1
  (make-immutable-hash
    '(
      (fcvt.q.h . 2)
      (fcvt.h.q . 2)
    )))
(define rv_q_zfhmin-rm
  (make-immutable-hash
    '(
      (fcvt.q.h . 3)
      (fcvt.h.q . 3)
    )))

(define rv_q_zfhmin-fields '(rd rs1 rm ))

(provide
  rv_q_zfhmin-rd
  rv_q_zfhmin-rs1
  rv_q_zfhmin-rm
  rv_q_zfhmin-fields)
