#lang racket

(define rv_zvbb-vm
  (make-immutable-hash
    '(
      (vandn.vv . 1)
      (vandn.vx . 1)
      (vbrev.v . 1)
      (vbrev8.v . 1)
      (vrev8.v . 1)
      (vclz.v . 1)
      (vctz.v . 1)
      (vcpop.v . 1)
      (vrol.vv . 1)
      (vrol.vx . 1)
      (vror.vv . 1)
      (vror.vx . 1)
      (vror.vi . 2)
      (vwsll.vv . 1)
      (vwsll.vx . 1)
      (vwsll.vi . 1)
    )))
(define rv_zvbb-vs2
  (make-immutable-hash
    '(
      (vandn.vv . 2)
      (vandn.vx . 2)
      (vbrev.v . 2)
      (vbrev8.v . 2)
      (vrev8.v . 2)
      (vclz.v . 2)
      (vctz.v . 2)
      (vcpop.v . 2)
      (vrol.vv . 2)
      (vrol.vx . 2)
      (vror.vv . 2)
      (vror.vx . 2)
      (vror.vi . 3)
      (vwsll.vv . 2)
      (vwsll.vx . 2)
      (vwsll.vi . 2)
    )))
(define rv_zvbb-vs1
  (make-immutable-hash
    '(
      (vandn.vv . 3)
      (vrol.vv . 3)
      (vror.vv . 3)
      (vwsll.vv . 3)
    )))
(define rv_zvbb-vd
  (make-immutable-hash
    '(
      (vandn.vv . 4)
      (vandn.vx . 4)
      (vbrev.v . 3)
      (vbrev8.v . 3)
      (vrev8.v . 3)
      (vclz.v . 3)
      (vctz.v . 3)
      (vcpop.v . 3)
      (vrol.vv . 4)
      (vrol.vx . 4)
      (vror.vv . 4)
      (vror.vx . 4)
      (vror.vi . 4)
      (vwsll.vv . 4)
      (vwsll.vx . 4)
      (vwsll.vi . 4)
    )))
(define rv_zvbb-rs1
  (make-immutable-hash
    '(
      (vandn.vx . 3)
      (vrol.vx . 3)
      (vror.vx . 3)
      (vwsll.vx . 3)
    )))
(define rv_zvbb-zimm6
  (make-immutable-hash
    '(
      (vror.vi . 1)
    )))
(define rv_zvbb-zimm5
  (make-immutable-hash
    '(
      (vwsll.vi . 3)
    )))

(define rv_zvbb-fields '(vm vs2 vs1 vd rs1 zimm6 zimm5 ))

(provide
  rv_zvbb-vm
  rv_zvbb-vs2
  rv_zvbb-vs1
  rv_zvbb-vd
  rv_zvbb-rs1
  rv_zvbb-zimm6
  rv_zvbb-zimm5
  rv_zvbb-fields)
