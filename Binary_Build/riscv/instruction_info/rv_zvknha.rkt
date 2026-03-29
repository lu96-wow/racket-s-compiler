#lang racket

(define rv_zvknha-25=1
  (make-immutable-hash
    '(
      (vsha2ms.vv . 1)
      (vsha2ch.vv . 1)
      (vsha2cl.vv . 1)
    )))
(define rv_zvknha-vs2
  (make-immutable-hash
    '(
      (vsha2ms.vv . 2)
      (vsha2ch.vv . 2)
      (vsha2cl.vv . 2)
    )))
(define rv_zvknha-vs1
  (make-immutable-hash
    '(
      (vsha2ms.vv . 3)
      (vsha2ch.vv . 3)
      (vsha2cl.vv . 3)
    )))
(define rv_zvknha-vd
  (make-immutable-hash
    '(
      (vsha2ms.vv . 4)
      (vsha2ch.vv . 4)
      (vsha2cl.vv . 4)
    )))

(define rv_zvknha-fields '(25=1 vs2 vs1 vd ))

(provide
  rv_zvknha-25=1
  rv_zvknha-vs2
  rv_zvknha-vs1
  rv_zvknha-vd
  rv_zvknha-fields)
