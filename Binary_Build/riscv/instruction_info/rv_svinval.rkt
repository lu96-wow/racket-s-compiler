#lang racket

(define rv_svinval-rs1
  (make-immutable-hash
    '(
      (sinval.vma . 1)
    )))
(define rv_svinval-rs2
  (make-immutable-hash
    '(
      (sinval.vma . 2)
    )))

(define rv_svinval-fields '(rs1 rs2 ))

(provide
  rv_svinval-rs1
  rv_svinval-rs2
  rv_svinval-fields)
