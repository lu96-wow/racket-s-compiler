#lang racket

(define rv32_d_zfa-rd
  (make-immutable-hash
    '(
      (fmvh.x.d . 1)
      (fmvp.d.x . 1)
    )))
(define rv32_d_zfa-rs1
  (make-immutable-hash
    '(
      (fmvh.x.d . 2)
      (fmvp.d.x . 2)
    )))
(define rv32_d_zfa-rs2
  (make-immutable-hash
    '(
      (fmvp.d.x . 3)
    )))

(define rv32_d_zfa-fields '(rd rs1 rs2 ))

(provide
  rv32_d_zfa-rd
  rv32_d_zfa-rs1
  rv32_d_zfa-rs2
  rv32_d_zfa-fields)
