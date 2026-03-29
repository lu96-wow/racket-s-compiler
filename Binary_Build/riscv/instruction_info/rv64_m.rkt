#lang racket

(define rv64_m-rd
  (make-immutable-hash
    '(
      (mulw . 1)
      (divw . 1)
      (divuw . 1)
      (remw . 1)
      (remuw . 1)
    )))
(define rv64_m-rs1
  (make-immutable-hash
    '(
      (mulw . 2)
      (divw . 2)
      (divuw . 2)
      (remw . 2)
      (remuw . 2)
    )))
(define rv64_m-rs2
  (make-immutable-hash
    '(
      (mulw . 3)
      (divw . 3)
      (divuw . 3)
      (remw . 3)
      (remuw . 3)
    )))

(define rv64_m-fields '(rd rs1 rs2 ))

(provide
  rv64_m-rd
  rv64_m-rs1
  rv64_m-rs2
  rv64_m-fields)
