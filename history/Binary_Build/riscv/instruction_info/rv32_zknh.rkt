#lang racket

(define rv32_zknh-rd
  (make-immutable-hash
    '(
      (sha512sum0r . 1)
      (sha512sum1r . 1)
      (sha512sig0l . 1)
      (sha512sig0h . 1)
      (sha512sig1l . 1)
      (sha512sig1h . 1)
    )))
(define rv32_zknh-rs1
  (make-immutable-hash
    '(
      (sha512sum0r . 2)
      (sha512sum1r . 2)
      (sha512sig0l . 2)
      (sha512sig0h . 2)
      (sha512sig1l . 2)
      (sha512sig1h . 2)
    )))
(define rv32_zknh-rs2
  (make-immutable-hash
    '(
      (sha512sum0r . 3)
      (sha512sum1r . 3)
      (sha512sig0l . 3)
      (sha512sig0h . 3)
      (sha512sig1l . 3)
      (sha512sig1h . 3)
    )))

(define rv32_zknh-fields '(rd rs1 rs2))

(define rv32_zknh-param-count
  (make-immutable-hash
    '(
      (sha512sum0r . 3)
      (sha512sum1r . 3)
      (sha512sig0l . 3)
      (sha512sig0h . 3)
      (sha512sig1l . 3)
      (sha512sig1h . 3)
    )))

(define rv32_zknh-operands
  (make-immutable-hash
    '(
      (sha512sum0r . (rd rs1 rs2))
      (sha512sum1r . (rd rs1 rs2))
      (sha512sig0l . (rd rs1 rs2))
      (sha512sig0h . (rd rs1 rs2))
      (sha512sig1l . (rd rs1 rs2))
      (sha512sig1h . (rd rs1 rs2))
    )))

(define rv32_zknh-asm
  (make-immutable-hash
    '(
      (sha512sum0r . "sha512sum0r rd, rs1, rs2")
      (sha512sum1r . "sha512sum1r rd, rs1, rs2")
      (sha512sig0l . "sha512sig0l rd, rs1, rs2")
      (sha512sig0h . "sha512sig0h rd, rs1, rs2")
      (sha512sig1l . "sha512sig1l rd, rs1, rs2")
      (sha512sig1h . "sha512sig1h rd, rs1, rs2")
    )))

(define rv32_zknh-operand-types
  (make-immutable-hash
    '(
      (sha512sum0r . (reg reg reg))
      (sha512sum1r . (reg reg reg))
      (sha512sig0l . (reg reg reg))
      (sha512sig0h . (reg reg reg))
      (sha512sig1l . (reg reg reg))
      (sha512sig1h . (reg reg reg))
    )))

(define rv32_zknh-width 32)

;; ====== Helper functions ======

(define (rv32_zknh-get-param-count mnemonic)
  (hash-ref rv32_zknh-param-count mnemonic #f))

(define (rv32_zknh-get-operands mnemonic)
  (hash-ref rv32_zknh-operands mnemonic '()))

(define (rv32_zknh-get-asm mnemonic)
  (hash-ref rv32_zknh-asm mnemonic #f))

(define (rv32_zknh-get-operand-types mnemonic)
  (hash-ref rv32_zknh-operand-types mnemonic '()))

(define (rv32_zknh-get-width) rv32_zknh-width)

(define (rv32_zknh-exists? mnemonic)
  (hash-has-key? rv32_zknh-param-count mnemonic))

(define (rv32_zknh-get-field-position mnemonic field)
  (case field
    [(rd) (hash-ref rv32_zknh-rd mnemonic #f)]
    [(rs1) (hash-ref rv32_zknh-rs1 mnemonic #f)]
    [(rs2) (hash-ref rv32_zknh-rs2 mnemonic #f)]
    [else #f]))

(provide
  rv32_zknh-rd
  rv32_zknh-rs1
  rv32_zknh-rs2
  rv32_zknh-fields
  rv32_zknh-param-count
  rv32_zknh-operands
  rv32_zknh-asm
  rv32_zknh-operand-types
  rv32_zknh-width
  rv32_zknh-get-param-count
  rv32_zknh-get-operands
  rv32_zknh-get-asm
  rv32_zknh-get-operand-types
  rv32_zknh-get-width
  rv32_zknh-exists?
  rv32_zknh-get-field-position)
