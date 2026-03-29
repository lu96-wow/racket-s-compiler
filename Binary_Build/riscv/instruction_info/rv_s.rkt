#lang racket

(define rv_s-rs1
  (make-immutable-hash
    '(
      (sfence.vma . 1)
    )))
(define rv_s-rs2
  (make-immutable-hash
    '(
      (sfence.vma . 2)
    )))

(define rv_s-fields '(rs1 rs2 ))

(provide
  rv_s-rs1
  rv_s-rs2
  rv_s-fields)
