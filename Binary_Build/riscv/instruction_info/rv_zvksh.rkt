#lang racket

(define rv_zvksh-vs2
  (make-immutable-hash
    '(
      (vsm3c.vi . 1)
      (vsm3me.vv . 1)
    )))
(define rv_zvksh-zimm5
  (make-immutable-hash
    '(
      (vsm3c.vi . 2)
    )))
(define rv_zvksh-vd
  (make-immutable-hash
    '(
      (vsm3c.vi . 3)
      (vsm3me.vv . 3)
    )))
(define rv_zvksh-vs1
  (make-immutable-hash
    '(
      (vsm3me.vv . 2)
    )))

(define rv_zvksh-fields '(vs2 zimm5 vd vs1 ))

(provide
  rv_zvksh-vs2
  rv_zvksh-zimm5
  rv_zvksh-vd
  rv_zvksh-vs1
  rv_zvksh-fields)
