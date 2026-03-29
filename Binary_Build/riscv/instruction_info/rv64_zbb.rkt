#lang racket

(define rv64_zbb-rd
  (make-immutable-hash
    '(
      (clzw . 1)
      (ctzw . 1)
      (cpopw . 1)
      (rolw . 1)
      (rorw . 1)
      (roriw . 1)
      (rori . 1)
      (rev8 . 1)
    )))
(define rv64_zbb-rs1
  (make-immutable-hash
    '(
      (clzw . 2)
      (ctzw . 2)
      (cpopw . 2)
      (rolw . 2)
      (rorw . 2)
      (roriw . 2)
      (rori . 2)
      (rev8 . 2)
    )))
(define rv64_zbb-rs2
  (make-immutable-hash
    '(
      (rolw . 3)
      (rorw . 3)
    )))
(define rv64_zbb-shamtw
  (make-immutable-hash
    '(
      (roriw . 3)
    )))
(define rv64_zbb-shamtd
  (make-immutable-hash
    '(
      (rori . 3)
    )))

(define rv64_zbb-fields '(rd rs1 rs2 shamtw shamtd ))

(provide
  rv64_zbb-rd
  rv64_zbb-rs1
  rv64_zbb-rs2
  rv64_zbb-shamtw
  rv64_zbb-shamtd
  rv64_zbb-fields)
