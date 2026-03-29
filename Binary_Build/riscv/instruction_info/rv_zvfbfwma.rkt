#lang racket

(define rv_zvfbfwma-vm
  (make-immutable-hash
    '(
      (vfwmaccbf16.vv . 1)
      (vfwmaccbf16.vf . 1)
    )))
(define rv_zvfbfwma-vs2
  (make-immutable-hash
    '(
      (vfwmaccbf16.vv . 2)
      (vfwmaccbf16.vf . 2)
    )))
(define rv_zvfbfwma-vs1
  (make-immutable-hash
    '(
      (vfwmaccbf16.vv . 3)
    )))
(define rv_zvfbfwma-vd
  (make-immutable-hash
    '(
      (vfwmaccbf16.vv . 4)
      (vfwmaccbf16.vf . 4)
    )))
(define rv_zvfbfwma-rs1
  (make-immutable-hash
    '(
      (vfwmaccbf16.vf . 3)
    )))

(define rv_zvfbfwma-fields '(vm vs2 vs1 vd rs1 ))

(provide
  rv_zvfbfwma-vm
  rv_zvfbfwma-vs2
  rv_zvfbfwma-vs1
  rv_zvfbfwma-vd
  rv_zvfbfwma-rs1
  rv_zvfbfwma-fields)
