#lang racket

(define rv64_zbs-rd
  (make-immutable-hash
    '(
      (bclri . 1)
      (bexti . 1)
      (binvi . 1)
      (bseti . 1)
    )))
(define rv64_zbs-rs1
  (make-immutable-hash
    '(
      (bclri . 2)
      (bexti . 2)
      (binvi . 2)
      (bseti . 2)
    )))
(define rv64_zbs-shamtd
  (make-immutable-hash
    '(
      (bclri . 3)
      (bexti . 3)
      (binvi . 3)
      (bseti . 3)
    )))

(define rv64_zbs-fields '(rd rs1 shamtd))

(define rv64_zbs-param-count
  (make-immutable-hash
    '(
      (bclri . 3)
      (bexti . 3)
      (binvi . 3)
      (bseti . 3)
    )))

(define rv64_zbs-operands
  (make-immutable-hash
    '(
      (bclri . (rd rs1 shamtd))
      (bexti . (rd rs1 shamtd))
      (binvi . (rd rs1 shamtd))
      (bseti . (rd rs1 shamtd))
    )))

(define rv64_zbs-asm
  (make-immutable-hash
    '(
      (bclri . "bclri rd, rs1, shamtd")
      (bexti . "bexti rd, rs1, shamtd")
      (binvi . "binvi rd, rs1, shamtd")
      (bseti . "bseti rd, rs1, shamtd")
    )))

(define rv64_zbs-operand-types
  (make-immutable-hash
    '(
      (bclri . (reg reg imm))
      (bexti . (reg reg imm))
      (binvi . (reg reg imm))
      (bseti . (reg reg imm))
    )))

(define rv64_zbs-width 32)

;; ====== Helper functions ======

(define (rv64_zbs-get-param-count mnemonic)
  (hash-ref rv64_zbs-param-count mnemonic #f))

(define (rv64_zbs-get-operands mnemonic)
  (hash-ref rv64_zbs-operands mnemonic '()))

(define (rv64_zbs-get-asm mnemonic)
  (hash-ref rv64_zbs-asm mnemonic #f))

(define (rv64_zbs-get-operand-types mnemonic)
  (hash-ref rv64_zbs-operand-types mnemonic '()))

(define (rv64_zbs-get-width) rv64_zbs-width)

(define (rv64_zbs-exists? mnemonic)
  (hash-has-key? rv64_zbs-param-count mnemonic))

(define (rv64_zbs-get-field-position mnemonic field)
  (case field
    [(rd) (hash-ref rv64_zbs-rd mnemonic #f)]
    [(rs1) (hash-ref rv64_zbs-rs1 mnemonic #f)]
    [(shamtd) (hash-ref rv64_zbs-shamtd mnemonic #f)]
    [else #f]))

(provide
  rv64_zbs-rd
  rv64_zbs-rs1
  rv64_zbs-shamtd
  rv64_zbs-fields
  rv64_zbs-param-count
  rv64_zbs-operands
  rv64_zbs-asm
  rv64_zbs-operand-types
  rv64_zbs-width
  rv64_zbs-get-param-count
  rv64_zbs-get-operands
  rv64_zbs-get-asm
  rv64_zbs-get-operand-types
  rv64_zbs-get-width
  rv64_zbs-exists?
  rv64_zbs-get-field-position)
