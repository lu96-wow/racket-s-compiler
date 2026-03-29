#lang racket

(define rv32_zknh-rd
  (make-immutable-hash
    '(
      (sha512sum0r . 1)
      (sha512sum1r . 1)
      (sha512sig0l . 1)
      (sha512sig0h . 1)
      (sha512sig1l . 1)
      (sha512sig1h . 1)
    )))
(define rv32_zknh-rs1
  (make-immutable-hash
    '(
      (sha512sum0r . 2)
      (sha512sum1r . 2)
      (sha512sig0l . 2)
      (sha512sig0h . 2)
      (sha512sig1l . 2)
      (sha512sig1h . 2)
    )))
(define rv32_zknh-rs2
  (make-immutable-hash
    '(
      (sha512sum0r . 3)
      (sha512sum1r . 3)
      (sha512sig0l . 3)
      (sha512sig0h . 3)
      (sha512sig1l . 3)
      (sha512sig1h . 3)
    )))

(define rv32_zknh-fields '(rd rs1 rs2 ))

(provide
  rv32_zknh-rd
  rv32_zknh-rs1
  rv32_zknh-rs2
  rv32_zknh-fields)
