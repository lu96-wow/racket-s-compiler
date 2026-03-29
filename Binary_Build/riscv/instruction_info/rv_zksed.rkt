#lang racket

(define rv_zksed-rd
  (make-immutable-hash
    '(
      (sm4ed . 1)
      (sm4ks . 1)
    )))
(define rv_zksed-rs1
  (make-immutable-hash
    '(
      (sm4ed . 2)
      (sm4ks . 2)
    )))
(define rv_zksed-rs2
  (make-immutable-hash
    '(
      (sm4ed . 3)
      (sm4ks . 3)
    )))
(define rv_zksed-bs
  (make-immutable-hash
    '(
      (sm4ed . 4)
      (sm4ks . 4)
    )))

(define rv_zksed-fields '(rd rs1 rs2 bs ))

(provide
  rv_zksed-rd
  rv_zksed-rs1
  rv_zksed-rs2
  rv_zksed-bs
  rv_zksed-fields)
