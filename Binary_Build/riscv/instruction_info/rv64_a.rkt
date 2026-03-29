#lang racket

(define rv64_a-rd
  (make-immutable-hash
    '(
      (lr.d . 1)
      (sc.d . 1)
      (amoswap.d . 1)
      (amoadd.d . 1)
      (amoxor.d . 1)
      (amoand.d . 1)
      (amoor.d . 1)
      (amomin.d . 1)
      (amomax.d . 1)
      (amominu.d . 1)
      (amomaxu.d . 1)
    )))
(define rv64_a-rs1
  (make-immutable-hash
    '(
      (lr.d . 2)
      (sc.d . 2)
      (amoswap.d . 2)
      (amoadd.d . 2)
      (amoxor.d . 2)
      (amoand.d . 2)
      (amoor.d . 2)
      (amomin.d . 2)
      (amomax.d . 2)
      (amominu.d . 2)
      (amomaxu.d . 2)
    )))
(define rv64_a-aq
  (make-immutable-hash
    '(
      (lr.d . 3)
      (sc.d . 4)
      (amoswap.d . 4)
      (amoadd.d . 4)
      (amoxor.d . 4)
      (amoand.d . 4)
      (amoor.d . 4)
      (amomin.d . 4)
      (amomax.d . 4)
      (amominu.d . 4)
      (amomaxu.d . 4)
    )))
(define rv64_a-rl
  (make-immutable-hash
    '(
      (lr.d . 4)
      (sc.d . 5)
      (amoswap.d . 5)
      (amoadd.d . 5)
      (amoxor.d . 5)
      (amoand.d . 5)
      (amoor.d . 5)
      (amomin.d . 5)
      (amomax.d . 5)
      (amominu.d . 5)
      (amomaxu.d . 5)
    )))
(define rv64_a-rs2
  (make-immutable-hash
    '(
      (sc.d . 3)
      (amoswap.d . 3)
      (amoadd.d . 3)
      (amoxor.d . 3)
      (amoand.d . 3)
      (amoor.d . 3)
      (amomin.d . 3)
      (amomax.d . 3)
      (amominu.d . 3)
      (amomaxu.d . 3)
    )))

(define rv64_a-fields '(rd rs1 aq rl rs2 ))

(provide
  rv64_a-rd
  rv64_a-rs1
  rv64_a-aq
  rv64_a-rl
  rv64_a-rs2
  rv64_a-fields)
