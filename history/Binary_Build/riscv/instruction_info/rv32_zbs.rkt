#lang racket


(define rv32_zbs-fields '())

(define rv32_zbs-param-count (make-immutable-hash '()))

(define rv32_zbs-operands (make-immutable-hash '()))

(define rv32_zbs-asm (make-immutable-hash '()))

(define rv32_zbs-operand-types (make-immutable-hash '()))

(define rv32_zbs-width 32)

;; ====== Helper functions ======

(define (rv32_zbs-get-param-count mnemonic)
  (hash-ref rv32_zbs-param-count mnemonic #f))

(define (rv32_zbs-get-operands mnemonic)
  (hash-ref rv32_zbs-operands mnemonic '()))

(define (rv32_zbs-get-asm mnemonic)
  (hash-ref rv32_zbs-asm mnemonic #f))

(define (rv32_zbs-get-operand-types mnemonic)
  (hash-ref rv32_zbs-operand-types mnemonic '()))

(define (rv32_zbs-get-width) rv32_zbs-width)

(define (rv32_zbs-exists? mnemonic)
  (hash-has-key? rv32_zbs-param-count mnemonic))

(define (rv32_zbs-get-field-position mnemonic field)
  (case field

    [else #f]))

(provide
  rv32_zbs-fields
  rv32_zbs-param-count
  rv32_zbs-operands
  rv32_zbs-asm
  rv32_zbs-operand-types
  rv32_zbs-width
  rv32_zbs-get-param-count
  rv32_zbs-get-operands
  rv32_zbs-get-asm
  rv32_zbs-get-operand-types
  rv32_zbs-get-width
  rv32_zbs-exists?
  rv32_zbs-get-field-position)
