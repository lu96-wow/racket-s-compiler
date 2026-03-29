#lang racket

(define rv64_zfh-rd
  (make-immutable-hash
    '(
      (fcvt.l.h . 1)
      (fcvt.lu.h . 1)
      (fcvt.h.l . 1)
      (fcvt.h.lu . 1)
    )))
(define rv64_zfh-rs1
  (make-immutable-hash
    '(
      (fcvt.l.h . 2)
      (fcvt.lu.h . 2)
      (fcvt.h.l . 2)
      (fcvt.h.lu . 2)
    )))
(define rv64_zfh-rm
  (make-immutable-hash
    '(
      (fcvt.l.h . 3)
      (fcvt.lu.h . 3)
      (fcvt.h.l . 3)
      (fcvt.h.lu . 3)
    )))

(define rv64_zfh-fields '(rd rs1 rm ))

(provide
  rv64_zfh-rd
  rv64_zfh-rs1
  rv64_zfh-rm
  rv64_zfh-fields)
