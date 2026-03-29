#lang racket

(define rv64_zbs-rd
  (make-immutable-hash
    '(
      (bclri . 1)
      (bexti . 1)
      (binvi . 1)
      (bseti . 1)
    )))
(define rv64_zbs-rs1
  (make-immutable-hash
    '(
      (bclri . 2)
      (bexti . 2)
      (binvi . 2)
      (bseti . 2)
    )))
(define rv64_zbs-shamtd
  (make-immutable-hash
    '(
      (bclri . 3)
      (bexti . 3)
      (binvi . 3)
      (bseti . 3)
    )))

(define rv64_zbs-fields '(rd rs1 shamtd ))

(provide
  rv64_zbs-rd
  rv64_zbs-rs1
  rv64_zbs-shamtd
  rv64_zbs-fields)
