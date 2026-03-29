#lang racket

(define rv_zbkb-rd
  (make-immutable-hash
    '(
      (pack . 1)
      (packh . 1)
      (brev8 . 1)
    )))
(define rv_zbkb-rs1
  (make-immutable-hash
    '(
      (pack . 2)
      (packh . 2)
      (brev8 . 2)
    )))
(define rv_zbkb-rs2
  (make-immutable-hash
    '(
      (pack . 3)
      (packh . 3)
    )))

(define rv_zbkb-fields '(rd rs1 rs2 ))

(provide
  rv_zbkb-rd
  rv_zbkb-rs1
  rv_zbkb-rs2
  rv_zbkb-fields)
