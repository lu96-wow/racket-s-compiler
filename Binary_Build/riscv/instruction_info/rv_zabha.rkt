#lang racket

(define rv_zabha-rd
  (make-immutable-hash
    '(
      (amoswap.b . 1)
      (amoadd.b . 1)
      (amoxor.b . 1)
      (amoand.b . 1)
      (amoor.b . 1)
      (amomin.b . 1)
      (amomax.b . 1)
      (amominu.b . 1)
      (amomaxu.b . 1)
      (amoswap.h . 1)
      (amoadd.h . 1)
      (amoxor.h . 1)
      (amoand.h . 1)
      (amoor.h . 1)
      (amomin.h . 1)
      (amomax.h . 1)
      (amominu.h . 1)
      (amomaxu.h . 1)
    )))
(define rv_zabha-rs1
  (make-immutable-hash
    '(
      (amoswap.b . 2)
      (amoadd.b . 2)
      (amoxor.b . 2)
      (amoand.b . 2)
      (amoor.b . 2)
      (amomin.b . 2)
      (amomax.b . 2)
      (amominu.b . 2)
      (amomaxu.b . 2)
      (amoswap.h . 2)
      (amoadd.h . 2)
      (amoxor.h . 2)
      (amoand.h . 2)
      (amoor.h . 2)
      (amomin.h . 2)
      (amomax.h . 2)
      (amominu.h . 2)
      (amomaxu.h . 2)
    )))
(define rv_zabha-rs2
  (make-immutable-hash
    '(
      (amoswap.b . 3)
      (amoadd.b . 3)
      (amoxor.b . 3)
      (amoand.b . 3)
      (amoor.b . 3)
      (amomin.b . 3)
      (amomax.b . 3)
      (amominu.b . 3)
      (amomaxu.b . 3)
      (amoswap.h . 3)
      (amoadd.h . 3)
      (amoxor.h . 3)
      (amoand.h . 3)
      (amoor.h . 3)
      (amomin.h . 3)
      (amomax.h . 3)
      (amominu.h . 3)
      (amomaxu.h . 3)
    )))
(define rv_zabha-aq
  (make-immutable-hash
    '(
      (amoswap.b . 4)
      (amoadd.b . 4)
      (amoxor.b . 4)
      (amoand.b . 4)
      (amoor.b . 4)
      (amomin.b . 4)
      (amomax.b . 4)
      (amominu.b . 4)
      (amomaxu.b . 4)
      (amoswap.h . 4)
      (amoadd.h . 4)
      (amoxor.h . 4)
      (amoand.h . 4)
      (amoor.h . 4)
      (amomin.h . 4)
      (amomax.h . 4)
      (amominu.h . 4)
      (amomaxu.h . 4)
    )))
(define rv_zabha-rl
  (make-immutable-hash
    '(
      (amoswap.b . 5)
      (amoadd.b . 5)
      (amoxor.b . 5)
      (amoand.b . 5)
      (amoor.b . 5)
      (amomin.b . 5)
      (amomax.b . 5)
      (amominu.b . 5)
      (amomaxu.b . 5)
      (amoswap.h . 5)
      (amoadd.h . 5)
      (amoxor.h . 5)
      (amoand.h . 5)
      (amoor.h . 5)
      (amomin.h . 5)
      (amomax.h . 5)
      (amominu.h . 5)
      (amomaxu.h . 5)
    )))

(define rv_zabha-fields '(rd rs1 rs2 aq rl ))

(provide
  rv_zabha-rd
  rv_zabha-rs1
  rv_zabha-rs2
  rv_zabha-aq
  rv_zabha-rl
  rv_zabha-fields)
