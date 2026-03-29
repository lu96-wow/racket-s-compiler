#lang racket

(define rv_zvbc-vm
  (make-immutable-hash
    '(
      (vclmul.vv . 1)
      (vclmul.vx . 1)
      (vclmulh.vv . 1)
      (vclmulh.vx . 1)
    )))
(define rv_zvbc-vs2
  (make-immutable-hash
    '(
      (vclmul.vv . 2)
      (vclmul.vx . 2)
      (vclmulh.vv . 2)
      (vclmulh.vx . 2)
    )))
(define rv_zvbc-vs1
  (make-immutable-hash
    '(
      (vclmul.vv . 3)
      (vclmulh.vv . 3)
    )))
(define rv_zvbc-vd
  (make-immutable-hash
    '(
      (vclmul.vv . 4)
      (vclmul.vx . 4)
      (vclmulh.vv . 4)
      (vclmulh.vx . 4)
    )))
(define rv_zvbc-rs1
  (make-immutable-hash
    '(
      (vclmul.vx . 3)
      (vclmulh.vx . 3)
    )))

(define rv_zvbc-fields '(vm vs2 vs1 vd rs1 ))

(provide
  rv_zvbc-vm
  rv_zvbc-vs2
  rv_zvbc-vs1
  rv_zvbc-vd
  rv_zvbc-rs1
  rv_zvbc-fields)
