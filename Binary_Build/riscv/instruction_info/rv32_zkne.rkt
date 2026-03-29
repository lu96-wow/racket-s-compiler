#lang racket

(define rv32_zkne-rd
  (make-immutable-hash
    '(
      (aes32esmi . 1)
      (aes32esi . 1)
    )))
(define rv32_zkne-rs1
  (make-immutable-hash
    '(
      (aes32esmi . 2)
      (aes32esi . 2)
    )))
(define rv32_zkne-rs2
  (make-immutable-hash
    '(
      (aes32esmi . 3)
      (aes32esi . 3)
    )))
(define rv32_zkne-bs
  (make-immutable-hash
    '(
      (aes32esmi . 4)
      (aes32esi . 4)
    )))

(define rv32_zkne-fields '(rd rs1 rs2 bs ))

(provide
  rv32_zkne-rd
  rv32_zkne-rs1
  rv32_zkne-rs2
  rv32_zkne-bs
  rv32_zkne-fields)
