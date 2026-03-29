#lang racket

(define rv_zcmop-c_mop_t
  (make-immutable-hash
    '(
      (c.mop.N . 1)
    )))

(define rv_zcmop-fields '(c_mop_t ))

(provide
  rv_zcmop-c_mop_t
  rv_zcmop-fields)
