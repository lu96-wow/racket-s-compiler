#lang racket


(define rv64_zks-fields '())

(define rv64_zks-param-count (make-immutable-hash '()))

(define rv64_zks-operands (make-immutable-hash '()))

(define rv64_zks-asm (make-immutable-hash '()))

(define rv64_zks-operand-types (make-immutable-hash '()))

(define rv64_zks-width 32)

;; ====== Helper functions ======

(define (rv64_zks-get-param-count mnemonic)
  (hash-ref rv64_zks-param-count mnemonic #f))

(define (rv64_zks-get-operands mnemonic)
  (hash-ref rv64_zks-operands mnemonic '()))

(define (rv64_zks-get-asm mnemonic)
  (hash-ref rv64_zks-asm mnemonic #f))

(define (rv64_zks-get-operand-types mnemonic)
  (hash-ref rv64_zks-operand-types mnemonic '()))

(define (rv64_zks-get-width) rv64_zks-width)

(define (rv64_zks-exists? mnemonic)
  (hash-has-key? rv64_zks-param-count mnemonic))

(define (rv64_zks-get-field-position mnemonic field)
  (case field

    [else #f]))

(provide
  rv64_zks-fields
  rv64_zks-param-count
  rv64_zks-operands
  rv64_zks-asm
  rv64_zks-operand-types
  rv64_zks-width
  rv64_zks-get-param-count
  rv64_zks-get-operands
  rv64_zks-get-asm
  rv64_zks-get-operand-types
  rv64_zks-get-width
  rv64_zks-exists?
  rv64_zks-get-field-position)
