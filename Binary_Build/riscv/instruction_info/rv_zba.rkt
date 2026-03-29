#lang racket

(define rv_zba-rd
  (make-immutable-hash
    '(
      (sh1add . 1)
      (sh2add . 1)
      (sh3add . 1)
    )))
(define rv_zba-rs1
  (make-immutable-hash
    '(
      (sh1add . 2)
      (sh2add . 2)
      (sh3add . 2)
    )))
(define rv_zba-rs2
  (make-immutable-hash
    '(
      (sh1add . 3)
      (sh2add . 3)
      (sh3add . 3)
    )))

(define rv_zba-fields '(rd rs1 rs2 ))

(provide
  rv_zba-rd
  rv_zba-rs1
  rv_zba-rs2
  rv_zba-fields)
