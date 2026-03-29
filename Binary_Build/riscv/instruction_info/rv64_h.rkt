#lang racket

(define rv64_h-rd
  (make-immutable-hash
    '(
      (hlv.wu . 1)
      (hlv.d . 1)
    )))
(define rv64_h-rs1
  (make-immutable-hash
    '(
      (hlv.wu . 2)
      (hlv.d . 2)
      (hsv.d . 1)
    )))
(define rv64_h-rs2
  (make-immutable-hash
    '(
      (hsv.d . 2)
    )))

(define rv64_h-fields '(rd rs1 rs2 ))

(provide
  rv64_h-rd
  rv64_h-rs1
  rv64_h-rs2
  rv64_h-fields)
