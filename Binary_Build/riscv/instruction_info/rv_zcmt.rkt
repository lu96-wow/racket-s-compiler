#lang racket

(define rv_zcmt-c_index
  (make-immutable-hash
    '(
      (cm.jalt . 1)
    )))

(define rv_zcmt-fields '(c_index ))

(provide
  rv_zcmt-c_index
  rv_zcmt-fields)
