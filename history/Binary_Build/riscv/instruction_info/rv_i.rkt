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
(define rv_i-simm12
  (make-immutable-hash
    '(
      (sb . 1)
      (sh . 1)
      (sw . 1)
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

(define rv_i-fields '(rd imm20 jimm20 rs1 imm12 bimm12 rs2 simm12 fm pred succ))

(define rv_i-param-count
  (make-immutable-hash
    '(
      (lui . 2)
      (auipc . 2)
      (jal . 2)
      (jalr . 3)
      (beq . 3)
      (bne . 3)
      (blt . 3)
      (bge . 3)
      (bltu . 3)
      (bgeu . 3)
      (lb . 3)
      (lh . 3)
      (lw . 3)
      (lbu . 3)
      (lhu . 3)
      (sb . 3)
      (sh . 3)
      (sw . 3)
      (addi . 3)
      (slti . 3)
      (sltiu . 3)
      (xori . 3)
      (ori . 3)
      (andi . 3)
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
      (fence . 5)
      (ecall . 0)
      (ebreak . 0)
    )))

(define rv_i-operands
  (make-immutable-hash
    '(
      (lui . (rd imm20))
      (auipc . (rd imm20))
      (jal . (rd jimm20))
      (jalr . (rd rs1 imm12))
      (beq . (bimm12 rs1 rs2))
      (bne . (bimm12 rs1 rs2))
      (blt . (bimm12 rs1 rs2))
      (bge . (bimm12 rs1 rs2))
      (bltu . (bimm12 rs1 rs2))
      (bgeu . (bimm12 rs1 rs2))
      (lb . (rd rs1 imm12))
      (lh . (rd rs1 imm12))
      (lw . (rd rs1 imm12))
      (lbu . (rd rs1 imm12))
      (lhu . (rd rs1 imm12))
      (sb . (simm12 rs1 rs2))
      (sh . (simm12 rs1 rs2))
      (sw . (simm12 rs1 rs2))
      (addi . (rd rs1 imm12))
      (slti . (rd rs1 imm12))
      (sltiu . (rd rs1 imm12))
      (xori . (rd rs1 imm12))
      (ori . (rd rs1 imm12))
      (andi . (rd rs1 imm12))
      (add . (rd rs1 rs2))
      (sub . (rd rs1 rs2))
      (sll . (rd rs1 rs2))
      (slt . (rd rs1 rs2))
      (sltu . (rd rs1 rs2))
      (xor . (rd rs1 rs2))
      (srl . (rd rs1 rs2))
      (sra . (rd rs1 rs2))
      (or . (rd rs1 rs2))
      (and . (rd rs1 rs2))
      (fence . (fm pred succ rs1 rd))
      (ecall . ())
      (ebreak . ())
    )))

(define rv_i-asm
  (make-immutable-hash
    '(
      (lui . "lui rd, imm20")
      (auipc . "auipc rd, imm20")
      (jal . "jal rd, jimm20")
      (jalr . "jalr rd, rs1, imm12")
      (beq . "beq bimm12, rs1, rs2")
      (bne . "bne bimm12, rs1, rs2")
      (blt . "blt bimm12, rs1, rs2")
      (bge . "bge bimm12, rs1, rs2")
      (bltu . "bltu bimm12, rs1, rs2")
      (bgeu . "bgeu bimm12, rs1, rs2")
      (lb . "lb rd, rs1, imm12")
      (lh . "lh rd, rs1, imm12")
      (lw . "lw rd, rs1, imm12")
      (lbu . "lbu rd, rs1, imm12")
      (lhu . "lhu rd, rs1, imm12")
      (sb . "sb simm12, rs1, rs2")
      (sh . "sh simm12, rs1, rs2")
      (sw . "sw simm12, rs1, rs2")
      (addi . "addi rd, rs1, imm12")
      (slti . "slti rd, rs1, imm12")
      (sltiu . "sltiu rd, rs1, imm12")
      (xori . "xori rd, rs1, imm12")
      (ori . "ori rd, rs1, imm12")
      (andi . "andi rd, rs1, imm12")
      (add . "add rd, rs1, rs2")
      (sub . "sub rd, rs1, rs2")
      (sll . "sll rd, rs1, rs2")
      (slt . "slt rd, rs1, rs2")
      (sltu . "sltu rd, rs1, rs2")
      (xor . "xor rd, rs1, rs2")
      (srl . "srl rd, rs1, rs2")
      (sra . "sra rd, rs1, rs2")
      (or . "or rd, rs1, rs2")
      (and . "and rd, rs1, rs2")
      (fence . "fence fm, pred, succ, rs1, rd")
      (ecall . "ecall")
      (ebreak . "ebreak")
    )))

(define rv_i-operand-types
  (make-immutable-hash
    '(
      (lui . (reg imm))
      (auipc . (reg imm))
      (jal . (reg imm))
      (jalr . (reg reg imm))
      (beq . (imm reg reg))
      (bne . (imm reg reg))
      (blt . (imm reg reg))
      (bge . (imm reg reg))
      (bltu . (imm reg reg))
      (bgeu . (imm reg reg))
      (lb . (reg reg imm))
      (lh . (reg reg imm))
      (lw . (reg reg imm))
      (lbu . (reg reg imm))
      (lhu . (reg reg imm))
      (sb . (imm reg reg))
      (sh . (imm reg reg))
      (sw . (imm reg reg))
      (addi . (reg reg imm))
      (slti . (reg reg imm))
      (sltiu . (reg reg imm))
      (xori . (reg reg imm))
      (ori . (reg reg imm))
      (andi . (reg reg imm))
      (add . (reg reg reg))
      (sub . (reg reg reg))
      (sll . (reg reg reg))
      (slt . (reg reg reg))
      (sltu . (reg reg reg))
      (xor . (reg reg reg))
      (srl . (reg reg reg))
      (sra . (reg reg reg))
      (or . (reg reg reg))
      (and . (reg reg reg))
      (fence . (imm imm imm reg reg))
      (ecall . ())
      (ebreak . ())
    )))

(define rv_i-width 32)

;; ====== Helper functions ======

(define (rv_i-get-param-count mnemonic)
  (hash-ref rv_i-param-count mnemonic #f))

(define (rv_i-get-operands mnemonic)
  (hash-ref rv_i-operands mnemonic '()))

(define (rv_i-get-asm mnemonic)
  (hash-ref rv_i-asm mnemonic #f))

(define (rv_i-get-operand-types mnemonic)
  (hash-ref rv_i-operand-types mnemonic '()))

(define (rv_i-get-width) rv_i-width)

(define (rv_i-exists? mnemonic)
  (hash-has-key? rv_i-param-count mnemonic))

(define (rv_i-get-field-position mnemonic field)
  (case field
    [(rd) (hash-ref rv_i-rd mnemonic #f)]
    [(imm20) (hash-ref rv_i-imm20 mnemonic #f)]
    [(jimm20) (hash-ref rv_i-jimm20 mnemonic #f)]
    [(rs1) (hash-ref rv_i-rs1 mnemonic #f)]
    [(imm12) (hash-ref rv_i-imm12 mnemonic #f)]
    [(bimm12) (hash-ref rv_i-bimm12 mnemonic #f)]
    [(rs2) (hash-ref rv_i-rs2 mnemonic #f)]
    [(simm12) (hash-ref rv_i-simm12 mnemonic #f)]
    [(fm) (hash-ref rv_i-fm mnemonic #f)]
    [(pred) (hash-ref rv_i-pred mnemonic #f)]
    [(succ) (hash-ref rv_i-succ mnemonic #f)]
    [else #f]))

(provide
  rv_i-rd
  rv_i-imm20
  rv_i-jimm20
  rv_i-rs1
  rv_i-imm12
  rv_i-bimm12
  rv_i-rs2
  rv_i-simm12
  rv_i-fm
  rv_i-pred
  rv_i-succ
  rv_i-fields
  rv_i-param-count
  rv_i-operands
  rv_i-asm
  rv_i-operand-types
  rv_i-width
  rv_i-get-param-count
  rv_i-get-operands
  rv_i-get-asm
  rv_i-get-operand-types
  rv_i-get-width
  rv_i-exists?
  rv_i-get-field-position)
