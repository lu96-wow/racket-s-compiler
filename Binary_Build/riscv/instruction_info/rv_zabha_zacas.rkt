#lang racket

(define rv_zabha_zacas-rd
  (make-immutable-hash
    '(
      (amocas.b . 1)
      (amocas.h . 1)
    )))
(define rv_zabha_zacas-rs1
  (make-immutable-hash
    '(
      (amocas.b . 2)
      (amocas.h . 2)
    )))
(define rv_zabha_zacas-rs2
  (make-immutable-hash
    '(
      (amocas.b . 3)
      (amocas.h . 3)
    )))
(define rv_zabha_zacas-aq
  (make-immutable-hash
    '(
      (amocas.b . 4)
      (amocas.h . 4)
    )))
(define rv_zabha_zacas-rl
  (make-immutable-hash
    '(
      (amocas.b . 5)
      (amocas.h . 5)
    )))

(define rv_zabha_zacas-fields '(rd rs1 rs2 aq rl ))

(provide
  rv_zabha_zacas-rd
  rv_zabha_zacas-rs1
  rv_zabha_zacas-rs2
  rv_zabha_zacas-aq
  rv_zabha_zacas-rl
  rv_zabha_zacas-fields)
