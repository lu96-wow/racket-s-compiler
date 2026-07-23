#lang racket


(define rv32_zks-fields '())

(define rv32_zks-param-count (make-immutable-hash '()))

(define rv32_zks-operands (make-immutable-hash '()))

(define rv32_zks-asm (make-immutable-hash '()))

(define rv32_zks-operand-types (make-immutable-hash '()))

(define rv32_zks-width 32)

;; ====== Helper functions ======

(define (rv32_zks-get-param-count mnemonic)
  (hash-ref rv32_zks-param-count mnemonic #f))

(define (rv32_zks-get-operands mnemonic)
  (hash-ref rv32_zks-operands mnemonic '()))

(define (rv32_zks-get-asm mnemonic)
  (hash-ref rv32_zks-asm mnemonic #f))

(define (rv32_zks-get-operand-types mnemonic)
  (hash-ref rv32_zks-operand-types mnemonic '()))

(define (rv32_zks-get-width) rv32_zks-width)

(define (rv32_zks-exists? mnemonic)
  (hash-has-key? rv32_zks-param-count mnemonic))

(define (rv32_zks-get-field-position mnemonic field)
  (case field

    [else #f]))

(provide
  rv32_zks-fields
  rv32_zks-param-count
  rv32_zks-operands
  rv32_zks-asm
  rv32_zks-operand-types
  rv32_zks-width
  rv32_zks-get-param-count
  rv32_zks-get-operands
  rv32_zks-get-asm
  rv32_zks-get-operand-types
  rv32_zks-get-width
  rv32_zks-exists?
  rv32_zks-get-field-position)
