#lang racket

(define rv_zvkg-vs2
  (make-immutable-hash
    '(
      (vgmul.vv . 1)
      (vghsh.vv . 1)
    )))
(define rv_zvkg-vd
  (make-immutable-hash
    '(
      (vgmul.vv . 2)
      (vghsh.vv . 3)
    )))
(define rv_zvkg-vs1
  (make-immutable-hash
    '(
      (vghsh.vv . 2)
    )))

(define rv_zvkg-fields '(vs2 vd vs1 ))

(provide
  rv_zvkg-vs2
  rv_zvkg-vd
  rv_zvkg-vs1
  rv_zvkg-fields)
