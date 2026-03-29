#lang racket

(define rv64_zknd-rd
  (make-immutable-hash
    '(
      (aes64dsm . 1)
      (aes64ds . 1)
      (aes64ks1i . 1)
      (aes64im . 1)
      (aes64ks2 . 1)
    )))
(define rv64_zknd-rs1
  (make-immutable-hash
    '(
      (aes64dsm . 2)
      (aes64ds . 2)
      (aes64ks1i . 2)
      (aes64im . 2)
      (aes64ks2 . 2)
    )))
(define rv64_zknd-rs2
  (make-immutable-hash
    '(
      (aes64dsm . 3)
      (aes64ds . 3)
      (aes64ks2 . 3)
    )))
(define rv64_zknd-rnum
  (make-immutable-hash
    '(
      (aes64ks1i . 3)
    )))

(define rv64_zknd-fields '(rd rs1 rs2 rnum ))

(provide
  rv64_zknd-rd
  rv64_zknd-rs1
  rv64_zknd-rs2
  rv64_zknd-rnum
  rv64_zknd-fields)
