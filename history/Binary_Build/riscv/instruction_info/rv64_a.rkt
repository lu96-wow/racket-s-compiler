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

(define rv64_a-fields '(rd rs1 aq rl rs2))

(define rv64_a-param-count
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

(define rv64_a-operands
  (make-immutable-hash
    '(
      (lr.d . (rd rs1 aq rl))
      (sc.d . (rd rs1 rs2 aq rl))
      (amoswap.d . (rd rs1 rs2 aq rl))
      (amoadd.d . (rd rs1 rs2 aq rl))
      (amoxor.d . (rd rs1 rs2 aq rl))
      (amoand.d . (rd rs1 rs2 aq rl))
      (amoor.d . (rd rs1 rs2 aq rl))
      (amomin.d . (rd rs1 rs2 aq rl))
      (amomax.d . (rd rs1 rs2 aq rl))
      (amominu.d . (rd rs1 rs2 aq rl))
      (amomaxu.d . (rd rs1 rs2 aq rl))
    )))

(define rv64_a-asm
  (make-immutable-hash
    '(
      (lr.d . "lr.d rd, rs1, aq, rl")
      (sc.d . "sc.d rd, rs1, rs2, aq, rl")
      (amoswap.d . "amoswap.d rd, rs1, rs2, aq, rl")
      (amoadd.d . "amoadd.d rd, rs1, rs2, aq, rl")
      (amoxor.d . "amoxor.d rd, rs1, rs2, aq, rl")
      (amoand.d . "amoand.d rd, rs1, rs2, aq, rl")
      (amoor.d . "amoor.d rd, rs1, rs2, aq, rl")
      (amomin.d . "amomin.d rd, rs1, rs2, aq, rl")
      (amomax.d . "amomax.d rd, rs1, rs2, aq, rl")
      (amominu.d . "amominu.d rd, rs1, rs2, aq, rl")
      (amomaxu.d . "amomaxu.d rd, rs1, rs2, aq, rl")
    )))

(define rv64_a-operand-types
  (make-immutable-hash
    '(
      (lr.d . (reg reg imm imm))
      (sc.d . (reg reg reg imm imm))
      (amoswap.d . (reg reg reg imm imm))
      (amoadd.d . (reg reg reg imm imm))
      (amoxor.d . (reg reg reg imm imm))
      (amoand.d . (reg reg reg imm imm))
      (amoor.d . (reg reg reg imm imm))
      (amomin.d . (reg reg reg imm imm))
      (amomax.d . (reg reg reg imm imm))
      (amominu.d . (reg reg reg imm imm))
      (amomaxu.d . (reg reg reg imm imm))
    )))

(define rv64_a-width 32)

;; ====== Helper functions ======

(define (rv64_a-get-param-count mnemonic)
  (hash-ref rv64_a-param-count mnemonic #f))

(define (rv64_a-get-operands mnemonic)
  (hash-ref rv64_a-operands mnemonic '()))

(define (rv64_a-get-asm mnemonic)
  (hash-ref rv64_a-asm mnemonic #f))

(define (rv64_a-get-operand-types mnemonic)
  (hash-ref rv64_a-operand-types mnemonic '()))

(define (rv64_a-get-width) rv64_a-width)

(define (rv64_a-exists? mnemonic)
  (hash-has-key? rv64_a-param-count mnemonic))

(define (rv64_a-get-field-position mnemonic field)
  (case field
    [(rd) (hash-ref rv64_a-rd mnemonic #f)]
    [(rs1) (hash-ref rv64_a-rs1 mnemonic #f)]
    [(aq) (hash-ref rv64_a-aq mnemonic #f)]
    [(rl) (hash-ref rv64_a-rl mnemonic #f)]
    [(rs2) (hash-ref rv64_a-rs2 mnemonic #f)]
    [else #f]))

(provide
  rv64_a-rd
  rv64_a-rs1
  rv64_a-aq
  rv64_a-rl
  rv64_a-rs2
  rv64_a-fields
  rv64_a-param-count
  rv64_a-operands
  rv64_a-asm
  rv64_a-operand-types
  rv64_a-width
  rv64_a-get-param-count
  rv64_a-get-operands
  rv64_a-get-asm
  rv64_a-get-operand-types
  rv64_a-get-width
  rv64_a-exists?
  rv64_a-get-field-position)
