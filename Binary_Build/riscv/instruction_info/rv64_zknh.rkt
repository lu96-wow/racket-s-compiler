#lang racket

(define rv64_zknh-rd
  (make-immutable-hash
    '(
      (sha512sum0 . 1)
      (sha512sum1 . 1)
      (sha512sig0 . 1)
      (sha512sig1 . 1)
    )))
(define rv64_zknh-rs1
  (make-immutable-hash
    '(
      (sha512sum0 . 2)
      (sha512sum1 . 2)
      (sha512sig0 . 2)
      (sha512sig1 . 2)
    )))

(define rv64_zknh-fields '(rd rs1))

(define rv64_zknh-param-count
  (make-immutable-hash
    '(
      (sha512sum0 . 2)
      (sha512sum1 . 2)
      (sha512sig0 . 2)
      (sha512sig1 . 2)
    )))

(define rv64_zknh-operands
  (make-immutable-hash
    '(
      (sha512sum0 . (rd rs1))
      (sha512sum1 . (rd rs1))
      (sha512sig0 . (rd rs1))
      (sha512sig1 . (rd rs1))
    )))

(define rv64_zknh-asm
  (make-immutable-hash
    '(
      (sha512sum0 . "sha512sum0 rd, rs1")
      (sha512sum1 . "sha512sum1 rd, rs1")
      (sha512sig0 . "sha512sig0 rd, rs1")
      (sha512sig1 . "sha512sig1 rd, rs1")
    )))

(define rv64_zknh-operand-types
  (make-immutable-hash
    '(
      (sha512sum0 . (reg reg))
      (sha512sum1 . (reg reg))
      (sha512sig0 . (reg reg))
      (sha512sig1 . (reg reg))
    )))

(define rv64_zknh-width 32)

;; ====== Helper functions ======

(define (rv64_zknh-get-param-count mnemonic)
  (hash-ref rv64_zknh-param-count mnemonic #f))

(define (rv64_zknh-get-operands mnemonic)
  (hash-ref rv64_zknh-operands mnemonic '()))

(define (rv64_zknh-get-asm mnemonic)
  (hash-ref rv64_zknh-asm mnemonic #f))

(define (rv64_zknh-get-operand-types mnemonic)
  (hash-ref rv64_zknh-operand-types mnemonic '()))

(define (rv64_zknh-get-width) rv64_zknh-width)

(define (rv64_zknh-exists? mnemonic)
  (hash-has-key? rv64_zknh-param-count mnemonic))

(define (rv64_zknh-get-field-position mnemonic field)
  (case field
    [(rd) (hash-ref rv64_zknh-rd mnemonic #f)]
    [(rs1) (hash-ref rv64_zknh-rs1 mnemonic #f)]
    [else #f]))

(provide
  rv64_zknh-rd
  rv64_zknh-rs1
  rv64_zknh-fields
  rv64_zknh-param-count
  rv64_zknh-operands
  rv64_zknh-asm
  rv64_zknh-operand-types
  rv64_zknh-width
  rv64_zknh-get-param-count
  rv64_zknh-get-operands
  rv64_zknh-get-asm
  rv64_zknh-get-operand-types
  rv64_zknh-get-width
  rv64_zknh-exists?
  rv64_zknh-get-field-position)
