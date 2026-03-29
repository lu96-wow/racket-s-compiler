#lang racket

(define rv64_zbkb-rd
  (make-immutable-hash
    '(
      (packw . 1)
    )))
(define rv64_zbkb-rs1
  (make-immutable-hash
    '(
      (packw . 2)
    )))
(define rv64_zbkb-rs2
  (make-immutable-hash
    '(
      (packw . 3)
    )))

(define rv64_zbkb-fields '(rd rs1 rs2 ))

(provide
  rv64_zbkb-rd
  rv64_zbkb-rs1
  rv64_zbkb-rs2
  rv64_zbkb-fields)
