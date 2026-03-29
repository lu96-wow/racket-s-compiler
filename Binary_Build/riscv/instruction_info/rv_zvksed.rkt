#lang racket

(define rv_zvksed-25=1
  (make-immutable-hash
    '(
      (vsm4k.vi . 1)
      (vsm4r.vv . 1)
      (vsm4r.vs . 1)
    )))
(define rv_zvksed-vs2
  (make-immutable-hash
    '(
      (vsm4k.vi . 2)
      (vsm4r.vv . 2)
      (vsm4r.vs . 2)
    )))
(define rv_zvksed-zimm5
  (make-immutable-hash
    '(
      (vsm4k.vi . 3)
    )))
(define rv_zvksed-vd
  (make-immutable-hash
    '(
      (vsm4k.vi . 4)
      (vsm4r.vv . 3)
      (vsm4r.vs . 3)
    )))

(define rv_zvksed-fields '(25=1 vs2 zimm5 vd ))

(provide
  rv_zvksed-25=1
  rv_zvksed-vs2
  rv_zvksed-zimm5
  rv_zvksed-vd
  rv_zvksed-fields)
