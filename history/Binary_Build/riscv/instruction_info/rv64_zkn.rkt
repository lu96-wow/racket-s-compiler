#lang racket


(define rv64_zkn-fields '())

(define rv64_zkn-param-count (make-immutable-hash '()))

(define rv64_zkn-operands (make-immutable-hash '()))

(define rv64_zkn-asm (make-immutable-hash '()))

(define rv64_zkn-operand-types (make-immutable-hash '()))

(define rv64_zkn-width 32)

;; ====== Helper functions ======

(define (rv64_zkn-get-param-count mnemonic)
  (hash-ref rv64_zkn-param-count mnemonic #f))

(define (rv64_zkn-get-operands mnemonic)
  (hash-ref rv64_zkn-operands mnemonic '()))

(define (rv64_zkn-get-asm mnemonic)
  (hash-ref rv64_zkn-asm mnemonic #f))

(define (rv64_zkn-get-operand-types mnemonic)
  (hash-ref rv64_zkn-operand-types mnemonic '()))

(define (rv64_zkn-get-width) rv64_zkn-width)

(define (rv64_zkn-exists? mnemonic)
  (hash-has-key? rv64_zkn-param-count mnemonic))

(define (rv64_zkn-get-field-position mnemonic field)
  (case field

    [else #f]))

(provide
  rv64_zkn-fields
  rv64_zkn-param-count
  rv64_zkn-operands
  rv64_zkn-asm
  rv64_zkn-operand-types
  rv64_zkn-width
  rv64_zkn-get-param-count
  rv64_zkn-get-operands
  rv64_zkn-get-asm
  rv64_zkn-get-operand-types
  rv64_zkn-get-width
  rv64_zkn-exists?
  rv64_zkn-get-field-position)
