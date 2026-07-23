#lang racket

(define rv_zicfiss-rd
  (make-immutable-hash
    '(
      (ssamoswap.w . 1)
      (ssamoswap.d . 1)
    )))
(define rv_zicfiss-rs1
  (make-immutable-hash
    '(
      (ssamoswap.w . 2)
      (ssamoswap.d . 2)
    )))
(define rv_zicfiss-rs2
  (make-immutable-hash
    '(
      (ssamoswap.w . 3)
      (ssamoswap.d . 3)
    )))
(define rv_zicfiss-aq
  (make-immutable-hash
    '(
      (ssamoswap.w . 4)
      (ssamoswap.d . 4)
    )))
(define rv_zicfiss-rl
  (make-immutable-hash
    '(
      (ssamoswap.w . 5)
      (ssamoswap.d . 5)
    )))

(define rv_zicfiss-fields '(rd rs1 rs2 aq rl))

(define rv_zicfiss-param-count
  (make-immutable-hash
    '(
      (ssamoswap.w . 5)
      (ssamoswap.d . 5)
    )))

(define rv_zicfiss-operands
  (make-immutable-hash
    '(
      (ssamoswap.w . (rd rs1 rs2 aq rl))
      (ssamoswap.d . (rd rs1 rs2 aq rl))
    )))

(define rv_zicfiss-asm
  (make-immutable-hash
    '(
      (ssamoswap.w . "ssamoswap.w rd, rs1, rs2, aq, rl")
      (ssamoswap.d . "ssamoswap.d rd, rs1, rs2, aq, rl")
    )))

(define rv_zicfiss-operand-types
  (make-immutable-hash
    '(
      (ssamoswap.w . (reg reg reg imm imm))
      (ssamoswap.d . (reg reg reg imm imm))
    )))

(define rv_zicfiss-width 32)

;; ====== Helper functions ======

(define (rv_zicfiss-get-param-count mnemonic)
  (hash-ref rv_zicfiss-param-count mnemonic #f))

(define (rv_zicfiss-get-operands mnemonic)
  (hash-ref rv_zicfiss-operands mnemonic '()))

(define (rv_zicfiss-get-asm mnemonic)
  (hash-ref rv_zicfiss-asm mnemonic #f))

(define (rv_zicfiss-get-operand-types mnemonic)
  (hash-ref rv_zicfiss-operand-types mnemonic '()))

(define (rv_zicfiss-get-width) rv_zicfiss-width)

(define (rv_zicfiss-exists? mnemonic)
  (hash-has-key? rv_zicfiss-param-count mnemonic))

(define (rv_zicfiss-get-field-position mnemonic field)
  (case field
    [(rd) (hash-ref rv_zicfiss-rd mnemonic #f)]
    [(rs1) (hash-ref rv_zicfiss-rs1 mnemonic #f)]
    [(rs2) (hash-ref rv_zicfiss-rs2 mnemonic #f)]
    [(aq) (hash-ref rv_zicfiss-aq mnemonic #f)]
    [(rl) (hash-ref rv_zicfiss-rl mnemonic #f)]
    [else #f]))

(provide
  rv_zicfiss-rd
  rv_zicfiss-rs1
  rv_zicfiss-rs2
  rv_zicfiss-aq
  rv_zicfiss-rl
  rv_zicfiss-fields
  rv_zicfiss-param-count
  rv_zicfiss-operands
  rv_zicfiss-asm
  rv_zicfiss-operand-types
  rv_zicfiss-width
  rv_zicfiss-get-param-count
  rv_zicfiss-get-operands
  rv_zicfiss-get-asm
  rv_zicfiss-get-operand-types
  rv_zicfiss-get-width
  rv_zicfiss-exists?
  rv_zicfiss-get-field-position)
