#lang racket


(define rv32_i-fields '())

(define rv32_i-param-count (make-immutable-hash '()))

(define rv32_i-operands (make-immutable-hash '()))

(define rv32_i-asm (make-immutable-hash '()))

(define rv32_i-operand-types (make-immutable-hash '()))

(define rv32_i-width 32)

;; ====== Helper functions ======

(define (rv32_i-get-param-count mnemonic)
  (hash-ref rv32_i-param-count mnemonic #f))

(define (rv32_i-get-operands mnemonic)
  (hash-ref rv32_i-operands mnemonic '()))

(define (rv32_i-get-asm mnemonic)
  (hash-ref rv32_i-asm mnemonic #f))

(define (rv32_i-get-operand-types mnemonic)
  (hash-ref rv32_i-operand-types mnemonic '()))

(define (rv32_i-get-width) rv32_i-width)

(define (rv32_i-exists? mnemonic)
  (hash-has-key? rv32_i-param-count mnemonic))

(define (rv32_i-get-field-position mnemonic field)
  (case field

    [else #f]))

(provide
  rv32_i-fields
  rv32_i-param-count
  rv32_i-operands
  rv32_i-asm
  rv32_i-operand-types
  rv32_i-width
  rv32_i-get-param-count
  rv32_i-get-operands
  rv32_i-get-asm
  rv32_i-get-operand-types
  rv32_i-get-width
  rv32_i-exists?
  rv32_i-get-field-position)
