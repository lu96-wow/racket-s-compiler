#lang racket

(define rv_zacas-rd
  (make-immutable-hash
    '(
      (amocas.w . 1)
      (amocas.d . 1)
    )))
(define rv_zacas-rs1
  (make-immutable-hash
    '(
      (amocas.w . 2)
      (amocas.d . 2)
    )))
(define rv_zacas-rs2
  (make-immutable-hash
    '(
      (amocas.w . 3)
      (amocas.d . 3)
    )))
(define rv_zacas-aq
  (make-immutable-hash
    '(
      (amocas.w . 4)
      (amocas.d . 4)
    )))
(define rv_zacas-rl
  (make-immutable-hash
    '(
      (amocas.w . 5)
      (amocas.d . 5)
    )))

(define rv_zacas-fields '(rd rs1 rs2 aq rl ))

(provide
  rv_zacas-rd
  rv_zacas-rs1
  rv_zacas-rs2
  rv_zacas-aq
  rv_zacas-rl
  rv_zacas-fields)
