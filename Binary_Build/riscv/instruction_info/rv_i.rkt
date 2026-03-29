#lang racket

(define rv_i-rd
  (make-immutable-hash
    '(
      (lui . 1)
      (auipc . 1)
      (jal . 1)
      (jalr . 1)
      (lb . 1)
      (lh . 1)
      (lw . 1)
      (lbu . 1)
      (lhu . 1)
      (addi . 1)
      (slti . 1)
      (sltiu . 1)
      (xori . 1)
      (ori . 1)
      (andi . 1)
      (add . 1)
      (sub . 1)
      (sll . 1)
      (slt . 1)
      (sltu . 1)
      (xor . 1)
      (srl . 1)
      (sra . 1)
      (or . 1)
      (and . 1)
      (fence . 5)
    )))
(define rv_i-imm20
  (make-immutable-hash
    '(
      (lui . 2)
      (auipc . 2)
    )))
(define rv_i-jimm20
  (make-immutable-hash
    '(
      (jal . 2)
    )))
(define rv_i-rs1
  (make-immutable-hash
    '(
      (jalr . 2)
      (beq . 2)
      (bne . 2)
      (blt . 2)
      (bge . 2)
      (bltu . 2)
      (bgeu . 2)
      (lb . 2)
      (lh . 2)
      (lw . 2)
      (lbu . 2)
      (lhu . 2)
      (sb . 2)
      (sh . 2)
      (sw . 2)
      (addi . 2)
      (slti . 2)
      (sltiu . 2)
      (xori . 2)
      (ori . 2)
      (andi . 2)
      (add . 2)
      (sub . 2)
      (sll . 2)
      (slt . 2)
      (sltu . 2)
      (xor . 2)
      (srl . 2)
      (sra . 2)
      (or . 2)
      (and . 2)
      (fence . 4)
    )))
(define rv_i-imm12
  (make-immutable-hash
    '(
      (jalr . 3)
      (lb . 3)
      (lh . 3)
      (lw . 3)
      (lbu . 3)
      (lhu . 3)
      (sb . 1)
      (sh . 1)
      (sw . 1)
      (addi . 3)
      (slti . 3)
      (sltiu . 3)
      (xori . 3)
      (ori . 3)
      (andi . 3)
    )))
(define rv_i-bimm12
  (make-immutable-hash
    '(
      (beq . 1)
      (bne . 1)
      (blt . 1)
      (bge . 1)
      (bltu . 1)
      (bgeu . 1)
    )))
(define rv_i-rs2
  (make-immutable-hash
    '(
      (beq . 3)
      (bne . 3)
      (blt . 3)
      (bge . 3)
      (bltu . 3)
      (bgeu . 3)
      (sb . 3)
      (sh . 3)
      (sw . 3)
      (add . 3)
      (sub . 3)
      (sll . 3)
      (slt . 3)
      (sltu . 3)
      (xor . 3)
      (srl . 3)
      (sra . 3)
      (or . 3)
      (and . 3)
    )))
(define rv_i-fm
  (make-immutable-hash
    '(
      (fence . 1)
    )))
(define rv_i-pred
  (make-immutable-hash
    '(
      (fence . 2)
    )))
(define rv_i-succ
  (make-immutable-hash
    '(
      (fence . 3)
    )))

(define rv_i-fields '(rd imm20 jimm20 rs1 imm12 bimm12 rs2 fm pred succ ))

(provide
  rv_i-rd
  rv_i-imm20
  rv_i-jimm20
  rv_i-rs1
  rv_i-imm12
  rv_i-bimm12
  rv_i-rs2
  rv_i-fm
  rv_i-pred
  rv_i-succ
  rv_i-fields)
