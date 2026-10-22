#lang racket


(define rv64_zk-fields '())

(define rv64_zk-param-count (make-immutable-hash '()))

(define rv64_zk-operands (make-immutable-hash '()))

(define rv64_zk-asm (make-immutable-hash '()))

(define rv64_zk-operand-types (make-immutable-hash '()))

(define rv64_zk-width 32)

;; ====== Helper functions ======

(define (rv64_zk-get-param-count mnemonic)
  (hash-ref rv64_zk-param-count mnemonic #f))

(define (rv64_zk-get-operands mnemonic)
  (hash-ref rv64_zk-operands mnemonic '()))

(define (rv64_zk-get-asm mnemonic)
  (hash-ref rv64_zk-asm mnemonic #f))

(define (rv64_zk-get-operand-types mnemonic)
  (hash-ref rv64_zk-operand-types mnemonic '()))

(define (rv64_zk-get-width) rv64_zk-width)

(define (rv64_zk-exists? mnemonic)
  (hash-has-key? rv64_zk-param-count mnemonic))

(define (rv64_zk-get-field-position mnemonic field)
  (case field

    [else #f]))

(provide
  rv64_zk-fields
  rv64_zk-param-count
  rv64_zk-operands
  rv64_zk-asm
  rv64_zk-operand-types
  rv64_zk-width
  rv64_zk-get-param-count
  rv64_zk-get-operands
  rv64_zk-get-asm
  rv64_zk-get-operand-types
  rv64_zk-get-width
  rv64_zk-exists?
  rv64_zk-get-field-position)
