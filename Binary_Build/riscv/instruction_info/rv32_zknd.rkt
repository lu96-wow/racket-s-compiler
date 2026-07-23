#lang racket

(define rv32_zknd-rd
  (make-immutable-hash
    '(
      (aes32dsmi . 1)
      (aes32dsi . 1)
    )))
(define rv32_zknd-rs1
  (make-immutable-hash
    '(
      (aes32dsmi . 2)
      (aes32dsi . 2)
    )))
(define rv32_zknd-rs2
  (make-immutable-hash
    '(
      (aes32dsmi . 3)
      (aes32dsi . 3)
    )))
(define rv32_zknd-bs
  (make-immutable-hash
    '(
      (aes32dsmi . 4)
      (aes32dsi . 4)
    )))

(define rv32_zknd-fields '(rd rs1 rs2 bs))

(define rv32_zknd-param-count
  (make-immutable-hash
    '(
      (aes32dsmi . 4)
      (aes32dsi . 4)
    )))

(define rv32_zknd-operands
  (make-immutable-hash
    '(
      (aes32dsmi . (rd rs1 rs2 bs))
      (aes32dsi . (rd rs1 rs2 bs))
    )))

(define rv32_zknd-asm
  (make-immutable-hash
    '(
      (aes32dsmi . "aes32dsmi rd, rs1, rs2, bs")
      (aes32dsi . "aes32dsi rd, rs1, rs2, bs")
    )))

(define rv32_zknd-operand-types
  (make-immutable-hash
    '(
      (aes32dsmi . (reg reg reg imm))
      (aes32dsi . (reg reg reg imm))
    )))

(define rv32_zknd-width 32)

;; ====== Helper functions ======

(define (rv32_zknd-get-param-count mnemonic)
  (hash-ref rv32_zknd-param-count mnemonic #f))

(define (rv32_zknd-get-operands mnemonic)
  (hash-ref rv32_zknd-operands mnemonic '()))

(define (rv32_zknd-get-asm mnemonic)
  (hash-ref rv32_zknd-asm mnemonic #f))

(define (rv32_zknd-get-operand-types mnemonic)
  (hash-ref rv32_zknd-operand-types mnemonic '()))

(define (rv32_zknd-get-width) rv32_zknd-width)

(define (rv32_zknd-exists? mnemonic)
  (hash-has-key? rv32_zknd-param-count mnemonic))

(define (rv32_zknd-get-field-position mnemonic field)
  (case field
    [(rd) (hash-ref rv32_zknd-rd mnemonic #f)]
    [(rs1) (hash-ref rv32_zknd-rs1 mnemonic #f)]
    [(rs2) (hash-ref rv32_zknd-rs2 mnemonic #f)]
    [(bs) (hash-ref rv32_zknd-bs mnemonic #f)]
    [else #f]))

(provide
  rv32_zknd-rd
  rv32_zknd-rs1
  rv32_zknd-rs2
  rv32_zknd-bs
  rv32_zknd-fields
  rv32_zknd-param-count
  rv32_zknd-operands
  rv32_zknd-asm
  rv32_zknd-operand-types
  rv32_zknd-width
  rv32_zknd-get-param-count
  rv32_zknd-get-operands
  rv32_zknd-get-asm
  rv32_zknd-get-operand-types
  rv32_zknd-get-width
  rv32_zknd-exists?
  rv32_zknd-get-field-position)
