#lang racket

(define rv_zksh-rd
  (make-immutable-hash
    '(
      (sm3p0 . 1)
      (sm3p1 . 1)
    )))
(define rv_zksh-rs1
  (make-immutable-hash
    '(
      (sm3p0 . 2)
      (sm3p1 . 2)
    )))

(define rv_zksh-fields '(rd rs1 ))

(provide
  rv_zksh-rd
  rv_zksh-rs1
  rv_zksh-fields)
