#lang racket

(define rv_zvkned-25=1
  (make-immutable-hash
    '(
      (vaesdf.vv . 1)
      (vaesdf.vs . 1)
      (vaesdm.vv . 1)
      (vaesdm.vs . 1)
      (vaesef.vv . 1)
      (vaesef.vs . 1)
      (vaesem.vv . 1)
      (vaesem.vs . 1)
      (vaesz.vs . 1)
      (vaeskf1.vi . 1)
      (vaeskf2.vi . 1)
    )))
(define rv_zvkned-vs2
  (make-immutable-hash
    '(
      (vaesdf.vv . 2)
      (vaesdf.vs . 2)
      (vaesdm.vv . 2)
      (vaesdm.vs . 2)
      (vaesef.vv . 2)
      (vaesef.vs . 2)
      (vaesem.vv . 2)
      (vaesem.vs . 2)
      (vaesz.vs . 2)
      (vaeskf1.vi . 2)
      (vaeskf2.vi . 2)
    )))
(define rv_zvkned-vd
  (make-immutable-hash
    '(
      (vaesdf.vv . 3)
      (vaesdf.vs . 3)
      (vaesdm.vv . 3)
      (vaesdm.vs . 3)
      (vaesef.vv . 3)
      (vaesef.vs . 3)
      (vaesem.vv . 3)
      (vaesem.vs . 3)
      (vaesz.vs . 3)
      (vaeskf1.vi . 4)
      (vaeskf2.vi . 4)
    )))
(define rv_zvkned-zimm5
  (make-immutable-hash
    '(
      (vaeskf1.vi . 3)
      (vaeskf2.vi . 3)
    )))

(define rv_zvkned-fields '(25=1 vs2 vd zimm5 ))

(provide
  rv_zvkned-25=1
  rv_zvkned-vs2
  rv_zvkned-vd
  rv_zvkned-zimm5
  rv_zvkned-fields)
