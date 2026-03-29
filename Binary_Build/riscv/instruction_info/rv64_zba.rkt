#lang racket

(define rv64_zba-rd
  (make-immutable-hash
    '(
      (add.uw . 1)
      (sh1add.uw . 1)
      (sh2add.uw . 1)
      (sh3add.uw . 1)
      (slli.uw . 1)
    )))
(define rv64_zba-rs1
  (make-immutable-hash
    '(
      (add.uw . 2)
      (sh1add.uw . 2)
      (sh2add.uw . 2)
      (sh3add.uw . 2)
      (slli.uw . 2)
    )))
(define rv64_zba-rs2
  (make-immutable-hash
    '(
      (add.uw . 3)
      (sh1add.uw . 3)
      (sh2add.uw . 3)
      (sh3add.uw . 3)
    )))
(define rv64_zba-shamtd
  (make-immutable-hash
    '(
      (slli.uw . 3)
    )))

(define rv64_zba-fields '(rd rs1 rs2 shamtd ))

(provide
  rv64_zba-rd
  rv64_zba-rs1
  rv64_zba-rs2
  rv64_zba-shamtd
  rv64_zba-fields)
