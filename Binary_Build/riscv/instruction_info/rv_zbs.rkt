#lang racket

(define rv_zbs-rd
  (make-immutable-hash
    '(
      (bclr . 1)
      (bext . 1)
      (binv . 1)
      (bset . 1)
    )))
(define rv_zbs-rs1
  (make-immutable-hash
    '(
      (bclr . 2)
      (bext . 2)
      (binv . 2)
      (bset . 2)
    )))
(define rv_zbs-rs2
  (make-immutable-hash
    '(
      (bclr . 3)
      (bext . 3)
      (binv . 3)
      (bset . 3)
    )))

(define rv_zbs-fields '(rd rs1 rs2 ))

(provide
  rv_zbs-rd
  rv_zbs-rs1
  rv_zbs-rs2
  rv_zbs-fields)
