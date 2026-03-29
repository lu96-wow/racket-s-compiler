#lang racket

(define rv_zicfiss-rd
  (make-immutable-hash
    '(
      (ssamoswap.w . 1)
      (ssamoswap.d . 1)
    )))
(define rv_zicfiss-rs1
  (make-immutable-hash
    '(
      (ssamoswap.w . 2)
      (ssamoswap.d . 2)
    )))
(define rv_zicfiss-rs2
  (make-immutable-hash
    '(
      (ssamoswap.w . 3)
      (ssamoswap.d . 3)
    )))
(define rv_zicfiss-aq
  (make-immutable-hash
    '(
      (ssamoswap.w . 4)
      (ssamoswap.d . 4)
    )))
(define rv_zicfiss-rl
  (make-immutable-hash
    '(
      (ssamoswap.w . 5)
      (ssamoswap.d . 5)
    )))

(define rv_zicfiss-fields '(rd rs1 rs2 aq rl ))

(provide
  rv_zicfiss-rd
  rv_zicfiss-rs1
  rv_zicfiss-rs2
  rv_zicfiss-aq
  rv_zicfiss-rl
  rv_zicfiss-fields)
