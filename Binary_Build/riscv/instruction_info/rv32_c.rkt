#lang racket

(define rv32_c-c_imm12
  (make-immutable-hash
    '(
      (c.jal . 1)
    )))

(define rv32_c-fields '(c_imm12 ))

(provide
  rv32_c-c_imm12
  rv32_c-fields)
