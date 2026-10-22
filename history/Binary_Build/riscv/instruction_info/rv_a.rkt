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

(define rv_a-fields '(rd rs1 aq rl rs2))

(define rv_a-param-count
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

(define rv_a-operands
  (make-immutable-hash
    '(
      (lr.w . (rd rs1 aq rl))
      (sc.w . (rd rs1 rs2 aq rl))
      (amoswap.w . (rd rs1 rs2 aq rl))
      (amoadd.w . (rd rs1 rs2 aq rl))
      (amoxor.w . (rd rs1 rs2 aq rl))
      (amoand.w . (rd rs1 rs2 aq rl))
      (amoor.w . (rd rs1 rs2 aq rl))
      (amomin.w . (rd rs1 rs2 aq rl))
      (amomax.w . (rd rs1 rs2 aq rl))
      (amominu.w . (rd rs1 rs2 aq rl))
      (amomaxu.w . (rd rs1 rs2 aq rl))
    )))

(define rv_a-asm
  (make-immutable-hash
    '(
      (lr.w . "lr.w rd, rs1, aq, rl")
      (sc.w . "sc.w rd, rs1, rs2, aq, rl")
      (amoswap.w . "amoswap.w rd, rs1, rs2, aq, rl")
      (amoadd.w . "amoadd.w rd, rs1, rs2, aq, rl")
      (amoxor.w . "amoxor.w rd, rs1, rs2, aq, rl")
      (amoand.w . "amoand.w rd, rs1, rs2, aq, rl")
      (amoor.w . "amoor.w rd, rs1, rs2, aq, rl")
      (amomin.w . "amomin.w rd, rs1, rs2, aq, rl")
      (amomax.w . "amomax.w rd, rs1, rs2, aq, rl")
      (amominu.w . "amominu.w rd, rs1, rs2, aq, rl")
      (amomaxu.w . "amomaxu.w rd, rs1, rs2, aq, rl")
    )))

(define rv_a-operand-types
  (make-immutable-hash
    '(
      (lr.w . (reg reg imm imm))
      (sc.w . (reg reg reg imm imm))
      (amoswap.w . (reg reg reg imm imm))
      (amoadd.w . (reg reg reg imm imm))
      (amoxor.w . (reg reg reg imm imm))
      (amoand.w . (reg reg reg imm imm))
      (amoor.w . (reg reg reg imm imm))
      (amomin.w . (reg reg reg imm imm))
      (amomax.w . (reg reg reg imm imm))
      (amominu.w . (reg reg reg imm imm))
      (amomaxu.w . (reg reg reg imm imm))
    )))

(define rv_a-width 32)

;; ====== Helper functions ======

(define (rv_a-get-param-count mnemonic)
  (hash-ref rv_a-param-count mnemonic #f))

(define (rv_a-get-operands mnemonic)
  (hash-ref rv_a-operands mnemonic '()))

(define (rv_a-get-asm mnemonic)
  (hash-ref rv_a-asm mnemonic #f))

(define (rv_a-get-operand-types mnemonic)
  (hash-ref rv_a-operand-types mnemonic '()))

(define (rv_a-get-width) rv_a-width)

(define (rv_a-exists? mnemonic)
  (hash-has-key? rv_a-param-count mnemonic))

(define (rv_a-get-field-position mnemonic field)
  (case field
    [(rd) (hash-ref rv_a-rd mnemonic #f)]
    [(rs1) (hash-ref rv_a-rs1 mnemonic #f)]
    [(aq) (hash-ref rv_a-aq mnemonic #f)]
    [(rl) (hash-ref rv_a-rl mnemonic #f)]
    [(rs2) (hash-ref rv_a-rs2 mnemonic #f)]
    [else #f]))

(provide
  rv_a-rd
  rv_a-rs1
  rv_a-aq
  rv_a-rl
  rv_a-rs2
  rv_a-fields
  rv_a-param-count
  rv_a-operands
  rv_a-asm
  rv_a-operand-types
  rv_a-width
  rv_a-get-param-count
  rv_a-get-operands
  rv_a-get-asm
  rv_a-get-operand-types
  rv_a-get-width
  rv_a-exists?
  rv_a-get-field-position)
