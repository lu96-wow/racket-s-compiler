#lang racket

(define rv64_zknh-rd
  (make-immutable-hash
    '(
      (sha512sum0 . 1)
      (sha512sum1 . 1)
      (sha512sig0 . 1)
      (sha512sig1 . 1)
    )))
(define rv64_zknh-rs1
  (make-immutable-hash
    '(
      (sha512sum0 . 2)
      (sha512sum1 . 2)
      (sha512sig0 . 2)
      (sha512sig1 . 2)
    )))

(define rv64_zknh-fields '(rd rs1 ))

(provide
  rv64_zknh-rd
  rv64_zknh-rs1
  rv64_zknh-fields)
