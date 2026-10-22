#lang racket

(define rv64_zkne-rd
  (make-immutable-hash
    '(
      (aes64esm . 1)
      (aes64es . 1)
    )))
(define rv64_zkne-rs1
  (make-immutable-hash
    '(
      (aes64esm . 2)
      (aes64es . 2)
    )))
(define rv64_zkne-rs2
  (make-immutable-hash
    '(
      (aes64esm . 3)
      (aes64es . 3)
    )))

(define rv64_zkne-fields '(rd rs1 rs2))

(define rv64_zkne-param-count
  (make-immutable-hash
    '(
      (aes64esm . 3)
      (aes64es . 3)
    )))

(define rv64_zkne-operands
  (make-immutable-hash
    '(
      (aes64esm . (rd rs1 rs2))
      (aes64es . (rd rs1 rs2))
    )))

(define rv64_zkne-asm
  (make-immutable-hash
    '(
      (aes64esm . "aes64esm rd, rs1, rs2")
      (aes64es . "aes64es rd, rs1, rs2")
    )))

(define rv64_zkne-operand-types
  (make-immutable-hash
    '(
      (aes64esm . (reg reg reg))
      (aes64es . (reg reg reg))
    )))

(define rv64_zkne-width 32)

;; ====== Helper functions ======

(define (rv64_zkne-get-param-count mnemonic)
  (hash-ref rv64_zkne-param-count mnemonic #f))

(define (rv64_zkne-get-operands mnemonic)
  (hash-ref rv64_zkne-operands mnemonic '()))

(define (rv64_zkne-get-asm mnemonic)
  (hash-ref rv64_zkne-asm mnemonic #f))

(define (rv64_zkne-get-operand-types mnemonic)
  (hash-ref rv64_zkne-operand-types mnemonic '()))

(define (rv64_zkne-get-width) rv64_zkne-width)

(define (rv64_zkne-exists? mnemonic)
  (hash-has-key? rv64_zkne-param-count mnemonic))

(define (rv64_zkne-get-field-position mnemonic field)
  (case field
    [(rd) (hash-ref rv64_zkne-rd mnemonic #f)]
    [(rs1) (hash-ref rv64_zkne-rs1 mnemonic #f)]
    [(rs2) (hash-ref rv64_zkne-rs2 mnemonic #f)]
    [else #f]))

(provide
  rv64_zkne-rd
  rv64_zkne-rs1
  rv64_zkne-rs2
  rv64_zkne-fields
  rv64_zkne-param-count
  rv64_zkne-operands
  rv64_zkne-asm
  rv64_zkne-operand-types
  rv64_zkne-width
  rv64_zkne-get-param-count
  rv64_zkne-get-operands
  rv64_zkne-get-asm
  rv64_zkne-get-operand-types
  rv64_zkne-get-width
  rv64_zkne-exists?
  rv64_zkne-get-field-position)
