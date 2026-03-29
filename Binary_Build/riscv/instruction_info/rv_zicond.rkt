#lang racket

(define rv_zicond-rd
  (make-immutable-hash
    '(
      (czero.eqz . 1)
      (czero.nez . 1)
    )))
(define rv_zicond-rs1
  (make-immutable-hash
    '(
      (czero.eqz . 2)
      (czero.nez . 2)
    )))
(define rv_zicond-rs2
  (make-immutable-hash
    '(
      (czero.eqz . 3)
      (czero.nez . 3)
    )))

(define rv_zicond-fields '(rd rs1 rs2 ))

(provide
  rv_zicond-rd
  rv_zicond-rs1
  rv_zicond-rs2
  rv_zicond-fields)
