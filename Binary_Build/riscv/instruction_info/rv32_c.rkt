#lang racket

(define rv32_c-c_imm12
  (make-immutable-hash
    '(
      (c.jal . 1)
    )))

(define rv32_c-fields '(c_imm12))

(define rv32_c-param-count
  (make-immutable-hash
    '(
      (c.jal . 1)
    )))

(define rv32_c-operands
  (make-immutable-hash
    '(
      (c.jal . (c_imm12))
    )))

(define rv32_c-asm
  (make-immutable-hash
    '(
      (c.jal . "c.jal c_imm12")
    )))

(define rv32_c-operand-types
  (make-immutable-hash
    '(
      (c.jal . (imm))
    )))

(define rv32_c-width 16)

;; ====== Helper functions ======

(define (rv32_c-get-param-count mnemonic)
  (hash-ref rv32_c-param-count mnemonic #f))

(define (rv32_c-get-operands mnemonic)
  (hash-ref rv32_c-operands mnemonic '()))

(define (rv32_c-get-asm mnemonic)
  (hash-ref rv32_c-asm mnemonic #f))

(define (rv32_c-get-operand-types mnemonic)
  (hash-ref rv32_c-operand-types mnemonic '()))

(define (rv32_c-get-width) rv32_c-width)

(define (rv32_c-exists? mnemonic)
  (hash-has-key? rv32_c-param-count mnemonic))

(define (rv32_c-get-field-position mnemonic field)
  (case field
    [(c_imm12) (hash-ref rv32_c-c_imm12 mnemonic #f)]
    [else #f]))

(provide
  rv32_c-c_imm12
  rv32_c-fields
  rv32_c-param-count
  rv32_c-operands
  rv32_c-asm
  rv32_c-operand-types
  rv32_c-width
  rv32_c-get-param-count
  rv32_c-get-operands
  rv32_c-get-asm
  rv32_c-get-operand-types
  rv32_c-get-width
  rv32_c-exists?
  rv32_c-get-field-position)
