#lang racket

(define rv_svinval_h-rs1
  (make-immutable-hash
    '(
      (hinval.vvma . 1)
      (hinval.gvma . 1)
    )))
(define rv_svinval_h-rs2
  (make-immutable-hash
    '(
      (hinval.vvma . 2)
      (hinval.gvma . 2)
    )))

(define rv_svinval_h-fields '(rs1 rs2 ))

(provide
  rv_svinval_h-rs1
  rv_svinval_h-rs2
  rv_svinval_h-fields)
