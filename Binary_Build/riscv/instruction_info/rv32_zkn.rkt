#lang racket


(define rv32_zkn-fields '())

(define rv32_zkn-param-count (make-immutable-hash '()))

(define rv32_zkn-operands (make-immutable-hash '()))

(define rv32_zkn-asm (make-immutable-hash '()))

(define rv32_zkn-operand-types (make-immutable-hash '()))

(define rv32_zkn-width 32)

;; ====== Helper functions ======

(define (rv32_zkn-get-param-count mnemonic)
  (hash-ref rv32_zkn-param-count mnemonic #f))

(define (rv32_zkn-get-operands mnemonic)
  (hash-ref rv32_zkn-operands mnemonic '()))

(define (rv32_zkn-get-asm mnemonic)
  (hash-ref rv32_zkn-asm mnemonic #f))

(define (rv32_zkn-get-operand-types mnemonic)
  (hash-ref rv32_zkn-operand-types mnemonic '()))

(define (rv32_zkn-get-width) rv32_zkn-width)

(define (rv32_zkn-exists? mnemonic)
  (hash-has-key? rv32_zkn-param-count mnemonic))

(define (rv32_zkn-get-field-position mnemonic field)
  (case field

    [else #f]))

(provide
  rv32_zkn-fields
  rv32_zkn-param-count
  rv32_zkn-operands
  rv32_zkn-asm
  rv32_zkn-operand-types
  rv32_zkn-width
  rv32_zkn-get-param-count
  rv32_zkn-get-operands
  rv32_zkn-get-asm
  rv32_zkn-get-operand-types
  rv32_zkn-get-width
  rv32_zkn-exists?
  rv32_zkn-get-field-position)
