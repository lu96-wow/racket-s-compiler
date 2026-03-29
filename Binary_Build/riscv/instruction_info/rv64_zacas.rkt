#lang racket

(define rv64_zacas-rd
  (make-immutable-hash
    '(
      (amocas.q . 1)
    )))
(define rv64_zacas-rs1
  (make-immutable-hash
    '(
      (amocas.q . 2)
    )))
(define rv64_zacas-rs2
  (make-immutable-hash
    '(
      (amocas.q . 3)
    )))
(define rv64_zacas-aq
  (make-immutable-hash
    '(
      (amocas.q . 4)
    )))
(define rv64_zacas-rl
  (make-immutable-hash
    '(
      (amocas.q . 5)
    )))

(define rv64_zacas-fields '(rd rs1 rs2 aq rl ))

(provide
  rv64_zacas-rd
  rv64_zacas-rs1
  rv64_zacas-rs2
  rv64_zacas-aq
  rv64_zacas-rl
  rv64_zacas-fields)
