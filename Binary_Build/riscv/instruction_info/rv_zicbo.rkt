#lang racket

(define rv_zicbo-rs1
  (make-immutable-hash
    '(
      (cbo.clean . 1)
      (cbo.flush . 1)
      (cbo.inval . 1)
      (cbo.zero . 1)
    )))

(define rv_zicbo-fields '(rs1 ))

(provide
  rv_zicbo-rs1
  rv_zicbo-fields)
