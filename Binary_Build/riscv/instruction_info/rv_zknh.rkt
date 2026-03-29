#lang racket

(define rv_zknh-rd
  (make-immutable-hash
    '(
      (sha256sum0 . 1)
      (sha256sum1 . 1)
      (sha256sig0 . 1)
      (sha256sig1 . 1)
    )))
(define rv_zknh-rs1
  (make-immutable-hash
    '(
      (sha256sum0 . 2)
      (sha256sum1 . 2)
      (sha256sig0 . 2)
      (sha256sig1 . 2)
    )))

(define rv_zknh-fields '(rd rs1 ))

(provide
  rv_zknh-rd
  rv_zknh-rs1
  rv_zknh-fields)
