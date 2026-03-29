#lang racket

(define rv32_zknd-rd
  (make-immutable-hash
    '(
      (aes32dsmi . 1)
      (aes32dsi . 1)
    )))
(define rv32_zknd-rs1
  (make-immutable-hash
    '(
      (aes32dsmi . 2)
      (aes32dsi . 2)
    )))
(define rv32_zknd-rs2
  (make-immutable-hash
    '(
      (aes32dsmi . 3)
      (aes32dsi . 3)
    )))
(define rv32_zknd-bs
  (make-immutable-hash
    '(
      (aes32dsmi . 4)
      (aes32dsi . 4)
    )))

(define rv32_zknd-fields '(rd rs1 rs2 bs ))

(provide
  rv32_zknd-rd
  rv32_zknd-rs1
  rv32_zknd-rs2
  rv32_zknd-bs
  rv32_zknd-fields)
