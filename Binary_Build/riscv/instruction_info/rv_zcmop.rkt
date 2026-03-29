#lang racket

(define rv_zcmop-c_mop_t
  (make-immutable-hash
    '(
      (c.mop.N . 1)
    )))
(define rv_zcmop-11=0
  (make-immutable-hash
    '(
      (c.mop.N . 2)
    )))
(define rv_zcmop-7=1
  (make-immutable-hash
    '(
      (c.mop.N . 3)
    )))
(define rv_zcmop-12=0
  (make-immutable-hash
    '(
      (c.mop.N . 4)
    )))

(define rv_zcmop-fields '(c_mop_t 11=0 7=1 12=0 ))

(provide
  rv_zcmop-c_mop_t
  rv_zcmop-11=0
  rv_zcmop-7=1
  rv_zcmop-12=0
  rv_zcmop-fields)
