#lang racket


(define rv32_zbb-fields '())

(define rv32_zbb-param-count (make-immutable-hash '()))

(define rv32_zbb-operands (make-immutable-hash '()))

(define rv32_zbb-asm (make-immutable-hash '()))

(define rv32_zbb-operand-types (make-immutable-hash '()))

(define rv32_zbb-width 32)

;; ====== Helper functions ======

(define (rv32_zbb-get-param-count mnemonic)
  (hash-ref rv32_zbb-param-count mnemonic #f))

(define (rv32_zbb-get-operands mnemonic)
  (hash-ref rv32_zbb-operands mnemonic '()))

(define (rv32_zbb-get-asm mnemonic)
  (hash-ref rv32_zbb-asm mnemonic #f))

(define (rv32_zbb-get-operand-types mnemonic)
  (hash-ref rv32_zbb-operand-types mnemonic '()))

(define (rv32_zbb-get-width) rv32_zbb-width)

(define (rv32_zbb-exists? mnemonic)
  (hash-has-key? rv32_zbb-param-count mnemonic))

(define (rv32_zbb-get-field-position mnemonic field)
  (case field

    [else #f]))

(provide
  rv32_zbb-fields
  rv32_zbb-param-count
  rv32_zbb-operands
  rv32_zbb-asm
  rv32_zbb-operand-types
  rv32_zbb-width
  rv32_zbb-get-param-count
  rv32_zbb-get-operands
  rv32_zbb-get-asm
  rv32_zbb-get-operand-types
  rv32_zbb-get-width
  rv32_zbb-exists?
  rv32_zbb-get-field-position)
