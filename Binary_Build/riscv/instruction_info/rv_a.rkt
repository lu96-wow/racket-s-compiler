#lang racket

(define rv_a-rd
  (make-immutable-hash
    '(
      (lr.w . 1)
      (sc.w . 1)
      (amoswap.w . 1)
      (amoadd.w . 1)
      (amoxor.w . 1)
      (amoand.w . 1)
      (amoor.w . 1)
      (amomin.w . 1)
      (amomax.w . 1)
      (amominu.w . 1)
      (amomaxu.w . 1)
    )))
(define rv_a-rs1
  (make-immutable-hash
    '(
      (lr.w . 2)
      (sc.w . 2)
      (amoswap.w . 2)
      (amoadd.w . 2)
      (amoxor.w . 2)
      (amoand.w . 2)
      (amoor.w . 2)
      (amomin.w . 2)
      (amomax.w . 2)
      (amominu.w . 2)
      (amomaxu.w . 2)
    )))
(define rv_a-aq
  (make-immutable-hash
    '(
      (lr.w . 3)
      (sc.w . 4)
      (amoswap.w . 4)
      (amoadd.w . 4)
      (amoxor.w . 4)
      (amoand.w . 4)
      (amoor.w . 4)
      (amomin.w . 4)
      (amomax.w . 4)
      (amominu.w . 4)
      (amomaxu.w . 4)
    )))
(define rv_a-rl
  (make-immutable-hash
    '(
      (lr.w . 4)
      (sc.w . 5)
      (amoswap.w . 5)
      (amoadd.w . 5)
      (amoxor.w . 5)
      (amoand.w . 5)
      (amoor.w . 5)
      (amomin.w . 5)
      (amomax.w . 5)
      (amominu.w . 5)
      (amomaxu.w . 5)
    )))
(define rv_a-rs2
  (make-immutable-hash
    '(
      (sc.w . 3)
      (amoswap.w . 3)
      (amoadd.w . 3)
      (amoxor.w . 3)
      (amoand.w . 3)
      (amoor.w . 3)
      (amomin.w . 3)
      (amomax.w . 3)
      (amominu.w . 3)
      (amomaxu.w . 3)
    )))

(define rv_a-fields '(rd rs1 aq rl rs2 ))

(provide
  rv_a-rd
  rv_a-rs1
  rv_a-aq
  rv_a-rl
  rv_a-rs2
  rv_a-fields)
