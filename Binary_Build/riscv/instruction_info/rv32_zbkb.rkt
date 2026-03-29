#lang racket

(define rv32_zbkb-rd
  (make-immutable-hash
    '(
      (zip . 1)
      (unzip . 1)
      (rev8.rv32 . 1)
    )))
(define rv32_zbkb-rs1
  (make-immutable-hash
    '(
      (zip . 2)
      (unzip . 2)
      (rev8.rv32 . 2)
    )))

(define rv32_zbkb-fields '(rd rs1 ))

(provide
  rv32_zbkb-rd
  rv32_zbkb-rs1
  rv32_zbkb-fields)
