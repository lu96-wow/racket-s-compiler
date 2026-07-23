#lang racket

(define rv32_zkne-rd
  (make-immutable-hash
    '(
      (aes32esmi . 1)
      (aes32esi . 1)
    )))
(define rv32_zkne-rs1
  (make-immutable-hash
    '(
      (aes32esmi . 2)
      (aes32esi . 2)
    )))
(define rv32_zkne-rs2
  (make-immutable-hash
    '(
      (aes32esmi . 3)
      (aes32esi . 3)
    )))
(define rv32_zkne-bs
  (make-immutable-hash
    '(
      (aes32esmi . 4)
      (aes32esi . 4)
    )))

(define rv32_zkne-fields '(rd rs1 rs2 bs))

(define rv32_zkne-param-count
  (make-immutable-hash
    '(
      (aes32esmi . 4)
      (aes32esi . 4)
    )))

(define rv32_zkne-operands
  (make-immutable-hash
    '(
      (aes32esmi . (rd rs1 rs2 bs))
      (aes32esi . (rd rs1 rs2 bs))
    )))

(define rv32_zkne-asm
  (make-immutable-hash
    '(
      (aes32esmi . "aes32esmi rd, rs1, rs2, bs")
      (aes32esi . "aes32esi rd, rs1, rs2, bs")
    )))

(define rv32_zkne-operand-types
  (make-immutable-hash
    '(
      (aes32esmi . (reg reg reg imm))
      (aes32esi . (reg reg reg imm))
    )))

(define rv32_zkne-width 32)

;; ====== Helper functions ======

(define (rv32_zkne-get-param-count mnemonic)
  (hash-ref rv32_zkne-param-count mnemonic #f))

(define (rv32_zkne-get-operands mnemonic)
  (hash-ref rv32_zkne-operands mnemonic '()))

(define (rv32_zkne-get-asm mnemonic)
  (hash-ref rv32_zkne-asm mnemonic #f))

(define (rv32_zkne-get-operand-types mnemonic)
  (hash-ref rv32_zkne-operand-types mnemonic '()))

(define (rv32_zkne-get-width) rv32_zkne-width)

(define (rv32_zkne-exists? mnemonic)
  (hash-has-key? rv32_zkne-param-count mnemonic))

(define (rv32_zkne-get-field-position mnemonic field)
  (case field
    [(rd) (hash-ref rv32_zkne-rd mnemonic #f)]
    [(rs1) (hash-ref rv32_zkne-rs1 mnemonic #f)]
    [(rs2) (hash-ref rv32_zkne-rs2 mnemonic #f)]
    [(bs) (hash-ref rv32_zkne-bs mnemonic #f)]
    [else #f]))

(provide
  rv32_zkne-rd
  rv32_zkne-rs1
  rv32_zkne-rs2
  rv32_zkne-bs
  rv32_zkne-fields
  rv32_zkne-param-count
  rv32_zkne-operands
  rv32_zkne-asm
  rv32_zkne-operand-types
  rv32_zkne-width
  rv32_zkne-get-param-count
  rv32_zkne-get-operands
  rv32_zkne-get-asm
  rv32_zkne-get-operand-types
  rv32_zkne-get-width
  rv32_zkne-exists?
  rv32_zkne-get-field-position)
