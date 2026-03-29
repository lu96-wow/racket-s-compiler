#lang racket

(define rv64_zkne-rd
  (make-immutable-hash
    '(
      (aes64esm . 1)
      (aes64es . 1)
    )))
(define rv64_zkne-rs1
  (make-immutable-hash
    '(
      (aes64esm . 2)
      (aes64es . 2)
    )))
(define rv64_zkne-rs2
  (make-immutable-hash
    '(
      (aes64esm . 3)
      (aes64es . 3)
    )))

(define rv64_zkne-fields '(rd rs1 rs2 ))

(provide
  rv64_zkne-rd
  rv64_zkne-rs1
  rv64_zkne-rs2
  rv64_zkne-fields)
