#lang racket

(define rv_zbkx-rd
  (make-immutable-hash
    '(
      (xperm4 . 1)
      (xperm8 . 1)
    )))
(define rv_zbkx-rs1
  (make-immutable-hash
    '(
      (xperm4 . 2)
      (xperm8 . 2)
    )))
(define rv_zbkx-rs2
  (make-immutable-hash
    '(
      (xperm4 . 3)
      (xperm8 . 3)
    )))

(define rv_zbkx-fields '(rd rs1 rs2 ))

(provide
  rv_zbkx-rd
  rv_zbkx-rs1
  rv_zbkx-rs2
  rv_zbkx-fields)
