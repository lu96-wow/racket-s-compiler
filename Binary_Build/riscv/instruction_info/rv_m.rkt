#lang racket

(define rv_m-rd
  (make-immutable-hash
    '(
      (mul . 1)
      (mulh . 1)
      (mulhsu . 1)
      (mulhu . 1)
      (div . 1)
      (divu . 1)
      (rem . 1)
      (remu . 1)
    )))
(define rv_m-rs1
  (make-immutable-hash
    '(
      (mul . 2)
      (mulh . 2)
      (mulhsu . 2)
      (mulhu . 2)
      (div . 2)
      (divu . 2)
      (rem . 2)
      (remu . 2)
    )))
(define rv_m-rs2
  (make-immutable-hash
    '(
      (mul . 3)
      (mulh . 3)
      (mulhsu . 3)
      (mulhu . 3)
      (div . 3)
      (divu . 3)
      (rem . 3)
      (remu . 3)
    )))

(define rv_m-fields '(rd rs1 rs2 ))

(provide
  rv_m-rd
  rv_m-rs1
  rv_m-rs2
  rv_m-fields)
