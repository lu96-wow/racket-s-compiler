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

(define rv_zabha-fields '(rd rs1 rs2 aq rl))

(define rv_zabha-param-count
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

(define rv_zabha-operands
  (make-immutable-hash
    '(
      (amoswap.b . (rd rs1 rs2 aq rl))
      (amoadd.b . (rd rs1 rs2 aq rl))
      (amoxor.b . (rd rs1 rs2 aq rl))
      (amoand.b . (rd rs1 rs2 aq rl))
      (amoor.b . (rd rs1 rs2 aq rl))
      (amomin.b . (rd rs1 rs2 aq rl))
      (amomax.b . (rd rs1 rs2 aq rl))
      (amominu.b . (rd rs1 rs2 aq rl))
      (amomaxu.b . (rd rs1 rs2 aq rl))
      (amoswap.h . (rd rs1 rs2 aq rl))
      (amoadd.h . (rd rs1 rs2 aq rl))
      (amoxor.h . (rd rs1 rs2 aq rl))
      (amoand.h . (rd rs1 rs2 aq rl))
      (amoor.h . (rd rs1 rs2 aq rl))
      (amomin.h . (rd rs1 rs2 aq rl))
      (amomax.h . (rd rs1 rs2 aq rl))
      (amominu.h . (rd rs1 rs2 aq rl))
      (amomaxu.h . (rd rs1 rs2 aq rl))
    )))

(define rv_zabha-asm
  (make-immutable-hash
    '(
      (amoswap.b . "amoswap.b rd, rs1, rs2, aq, rl")
      (amoadd.b . "amoadd.b rd, rs1, rs2, aq, rl")
      (amoxor.b . "amoxor.b rd, rs1, rs2, aq, rl")
      (amoand.b . "amoand.b rd, rs1, rs2, aq, rl")
      (amoor.b . "amoor.b rd, rs1, rs2, aq, rl")
      (amomin.b . "amomin.b rd, rs1, rs2, aq, rl")
      (amomax.b . "amomax.b rd, rs1, rs2, aq, rl")
      (amominu.b . "amominu.b rd, rs1, rs2, aq, rl")
      (amomaxu.b . "amomaxu.b rd, rs1, rs2, aq, rl")
      (amoswap.h . "amoswap.h rd, rs1, rs2, aq, rl")
      (amoadd.h . "amoadd.h rd, rs1, rs2, aq, rl")
      (amoxor.h . "amoxor.h rd, rs1, rs2, aq, rl")
      (amoand.h . "amoand.h rd, rs1, rs2, aq, rl")
      (amoor.h . "amoor.h rd, rs1, rs2, aq, rl")
      (amomin.h . "amomin.h rd, rs1, rs2, aq, rl")
      (amomax.h . "amomax.h rd, rs1, rs2, aq, rl")
      (amominu.h . "amominu.h rd, rs1, rs2, aq, rl")
      (amomaxu.h . "amomaxu.h rd, rs1, rs2, aq, rl")
    )))

(define rv_zabha-operand-types
  (make-immutable-hash
    '(
      (amoswap.b . (reg reg reg imm imm))
      (amoadd.b . (reg reg reg imm imm))
      (amoxor.b . (reg reg reg imm imm))
      (amoand.b . (reg reg reg imm imm))
      (amoor.b . (reg reg reg imm imm))
      (amomin.b . (reg reg reg imm imm))
      (amomax.b . (reg reg reg imm imm))
      (amominu.b . (reg reg reg imm imm))
      (amomaxu.b . (reg reg reg imm imm))
      (amoswap.h . (reg reg reg imm imm))
      (amoadd.h . (reg reg reg imm imm))
      (amoxor.h . (reg reg reg imm imm))
      (amoand.h . (reg reg reg imm imm))
      (amoor.h . (reg reg reg imm imm))
      (amomin.h . (reg reg reg imm imm))
      (amomax.h . (reg reg reg imm imm))
      (amominu.h . (reg reg reg imm imm))
      (amomaxu.h . (reg reg reg imm imm))
    )))

(define rv_zabha-width 32)

;; ====== Helper functions ======

(define (rv_zabha-get-param-count mnemonic)
  (hash-ref rv_zabha-param-count mnemonic #f))

(define (rv_zabha-get-operands mnemonic)
  (hash-ref rv_zabha-operands mnemonic '()))

(define (rv_zabha-get-asm mnemonic)
  (hash-ref rv_zabha-asm mnemonic #f))

(define (rv_zabha-get-operand-types mnemonic)
  (hash-ref rv_zabha-operand-types mnemonic '()))

(define (rv_zabha-get-width) rv_zabha-width)

(define (rv_zabha-exists? mnemonic)
  (hash-has-key? rv_zabha-param-count mnemonic))

(define (rv_zabha-get-field-position mnemonic field)
  (case field
    [(rd) (hash-ref rv_zabha-rd mnemonic #f)]
    [(rs1) (hash-ref rv_zabha-rs1 mnemonic #f)]
    [(rs2) (hash-ref rv_zabha-rs2 mnemonic #f)]
    [(aq) (hash-ref rv_zabha-aq mnemonic #f)]
    [(rl) (hash-ref rv_zabha-rl mnemonic #f)]
    [else #f]))

(provide
  rv_zabha-rd
  rv_zabha-rs1
  rv_zabha-rs2
  rv_zabha-aq
  rv_zabha-rl
  rv_zabha-fields
  rv_zabha-param-count
  rv_zabha-operands
  rv_zabha-asm
  rv_zabha-operand-types
  rv_zabha-width
  rv_zabha-get-param-count
  rv_zabha-get-operands
  rv_zabha-get-asm
  rv_zabha-get-operand-types
  rv_zabha-get-width
  rv_zabha-exists?
  rv_zabha-get-field-position)
