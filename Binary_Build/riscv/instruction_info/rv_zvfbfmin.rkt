#lang racket

(define rv_zvfbfmin-vm
  (make-immutable-hash
    '(
      (vfncvtbf16.f.f.w . 1)
      (vfwcvtbf16.f.f.v . 1)
    )))
(define rv_zvfbfmin-vs2
  (make-immutable-hash
    '(
      (vfncvtbf16.f.f.w . 2)
      (vfwcvtbf16.f.f.v . 2)
    )))
(define rv_zvfbfmin-vd
  (make-immutable-hash
    '(
      (vfncvtbf16.f.f.w . 3)
      (vfwcvtbf16.f.f.v . 3)
    )))

(define rv_zvfbfmin-fields '(vm vs2 vd ))

(provide
  rv_zvfbfmin-vm
  rv_zvfbfmin-vs2
  rv_zvfbfmin-vd
  rv_zvfbfmin-fields)
