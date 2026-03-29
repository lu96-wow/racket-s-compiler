#lang racket

(define rv_zifencei-imm12
  (make-immutable-hash
    '(
      (fence.i . 1)
    )))
(define rv_zifencei-rs1
  (make-immutable-hash
    '(
      (fence.i . 2)
    )))
(define rv_zifencei-rd
  (make-immutable-hash
    '(
      (fence.i . 3)
    )))

(define rv_zifencei-fields '(imm12 rs1 rd ))

(provide
  rv_zifencei-imm12
  rv_zifencei-rs1
  rv_zifencei-rd
  rv_zifencei-fields)
