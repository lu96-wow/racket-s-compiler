#lang racket


(define rv32_zk-fields '())

(define rv32_zk-param-count (make-immutable-hash '()))

(define rv32_zk-operands (make-immutable-hash '()))

(define rv32_zk-asm (make-immutable-hash '()))

(define rv32_zk-operand-types (make-immutable-hash '()))

(define rv32_zk-width 32)

;; ====== Helper functions ======

(define (rv32_zk-get-param-count mnemonic)
  (hash-ref rv32_zk-param-count mnemonic #f))

(define (rv32_zk-get-operands mnemonic)
  (hash-ref rv32_zk-operands mnemonic '()))

(define (rv32_zk-get-asm mnemonic)
  (hash-ref rv32_zk-asm mnemonic #f))

(define (rv32_zk-get-operand-types mnemonic)
  (hash-ref rv32_zk-operand-types mnemonic '()))

(define (rv32_zk-get-width) rv32_zk-width)

(define (rv32_zk-exists? mnemonic)
  (hash-has-key? rv32_zk-param-count mnemonic))

(define (rv32_zk-get-field-position mnemonic field)
  (case field

    [else #f]))

(provide
  rv32_zk-fields
  rv32_zk-param-count
  rv32_zk-operands
  rv32_zk-asm
  rv32_zk-operand-types
  rv32_zk-width
  rv32_zk-get-param-count
  rv32_zk-get-operands
  rv32_zk-get-asm
  rv32_zk-get-operand-types
  rv32_zk-get-width
  rv32_zk-exists?
  rv32_zk-get-field-position)
