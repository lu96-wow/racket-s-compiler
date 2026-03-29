#lang racket

(define rv64_q_zfa-rd
  (make-immutable-hash
    '(
      (fmvh.x.q . 1)
      (fmvp.q.x . 1)
    )))
(define rv64_q_zfa-rs1
  (make-immutable-hash
    '(
      (fmvh.x.q . 2)
      (fmvp.q.x . 2)
    )))
(define rv64_q_zfa-rs2
  (make-immutable-hash
    '(
      (fmvp.q.x . 3)
    )))

(define rv64_q_zfa-fields '(rd rs1 rs2 ))

(provide
  rv64_q_zfa-rd
  rv64_q_zfa-rs1
  rv64_q_zfa-rs2
  rv64_q_zfa-fields)
