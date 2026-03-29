#lang racket

(define rv_zbb-rd
  (make-immutable-hash
    '(
      (andn . 1)
      (orn . 1)
      (xnor . 1)
      (clz . 1)
      (ctz . 1)
      (cpop . 1)
      (max . 1)
      (maxu . 1)
      (min . 1)
      (minu . 1)
      (sext.b . 1)
      (sext.h . 1)
      (rol . 1)
      (ror . 1)
      (orc.b . 1)
    )))
(define rv_zbb-rs1
  (make-immutable-hash
    '(
      (andn . 2)
      (orn . 2)
      (xnor . 2)
      (clz . 2)
      (ctz . 2)
      (cpop . 2)
      (max . 2)
      (maxu . 2)
      (min . 2)
      (minu . 2)
      (sext.b . 2)
      (sext.h . 2)
      (rol . 2)
      (ror . 2)
      (orc.b . 2)
    )))
(define rv_zbb-rs2
  (make-immutable-hash
    '(
      (andn . 3)
      (orn . 3)
      (xnor . 3)
      (max . 3)
      (maxu . 3)
      (min . 3)
      (minu . 3)
      (rol . 3)
      (ror . 3)
    )))

(define rv_zbb-fields '(rd rs1 rs2 ))

(provide
  rv_zbb-rd
  rv_zbb-rs1
  rv_zbb-rs2
  rv_zbb-fields)
