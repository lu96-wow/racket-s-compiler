#lang racket

(define rv_zvksed-vs2
  (make-immutable-hash
    '(
      (vsm4k.vi . 1)
      (vsm4r.vv . 1)
      (vsm4r.vs . 1)
    )))
(define rv_zvksed-zimm5
  (make-immutable-hash
    '(
      (vsm4k.vi . 2)
    )))
(define rv_zvksed-vd
  (make-immutable-hash
    '(
      (vsm4k.vi . 3)
      (vsm4r.vv . 2)
      (vsm4r.vs . 2)
    )))

(define rv_zvksed-fields '(vs2 zimm5 vd ))

(provide
  rv_zvksed-vs2
  rv_zvksed-zimm5
  rv_zvksed-vd
  rv_zvksed-fields)
