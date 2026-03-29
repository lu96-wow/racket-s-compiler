#lang racket

(define rv_zfbfmin-rd
  (make-immutable-hash
    '(
      (fcvt.bf16.s . 1)
      (fcvt.s.bf16 . 1)
    )))
(define rv_zfbfmin-rs1
  (make-immutable-hash
    '(
      (fcvt.bf16.s . 2)
      (fcvt.s.bf16 . 2)
    )))
(define rv_zfbfmin-rm
  (make-immutable-hash
    '(
      (fcvt.bf16.s . 3)
      (fcvt.s.bf16 . 3)
    )))

(define rv_zfbfmin-fields '(rd rs1 rm ))

(provide
  rv_zfbfmin-rd
  rv_zfbfmin-rs1
  rv_zfbfmin-rm
  rv_zfbfmin-fields)
