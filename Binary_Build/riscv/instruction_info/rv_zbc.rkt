#lang racket

(define rv_zbc-rd
  (make-immutable-hash
    '(
      (clmul . 1)
      (clmulr . 1)
      (clmulh . 1)
    )))
(define rv_zbc-rs1
  (make-immutable-hash
    '(
      (clmul . 2)
      (clmulr . 2)
      (clmulh . 2)
    )))
(define rv_zbc-rs2
  (make-immutable-hash
    '(
      (clmul . 3)
      (clmulr . 3)
      (clmulh . 3)
    )))

(define rv_zbc-fields '(rd rs1 rs2 ))

(provide
  rv_zbc-rd
  rv_zbc-rs1
  rv_zbc-rs2
  rv_zbc-fields)
