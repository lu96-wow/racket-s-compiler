#lang racket


(define rv32_zilsd-fields '())

(define rv32_zilsd-param-count (make-immutable-hash '()))

(define rv32_zilsd-operands (make-immutable-hash '()))

(define rv32_zilsd-asm (make-immutable-hash '()))

(define rv32_zilsd-operand-types (make-immutable-hash '()))

(define rv32_zilsd-width 32)

;; ====== Helper functions ======

(define (rv32_zilsd-get-param-count mnemonic)
  (hash-ref rv32_zilsd-param-count mnemonic #f))

(define (rv32_zilsd-get-operands mnemonic)
  (hash-ref rv32_zilsd-operands mnemonic '()))

(define (rv32_zilsd-get-asm mnemonic)
  (hash-ref rv32_zilsd-asm mnemonic #f))

(define (rv32_zilsd-get-operand-types mnemonic)
  (hash-ref rv32_zilsd-operand-types mnemonic '()))

(define (rv32_zilsd-get-width) rv32_zilsd-width)

(define (rv32_zilsd-exists? mnemonic)
  (hash-has-key? rv32_zilsd-param-count mnemonic))

(define (rv32_zilsd-get-field-position mnemonic field)
  (case field

    [else #f]))

(provide
  rv32_zilsd-fields
  rv32_zilsd-param-count
  rv32_zilsd-operands
  rv32_zilsd-asm
  rv32_zilsd-operand-types
  rv32_zilsd-width
  rv32_zilsd-get-param-count
  rv32_zilsd-get-operands
  rv32_zilsd-get-asm
  rv32_zilsd-get-operand-types
  rv32_zilsd-get-width
  rv32_zilsd-exists?
  rv32_zilsd-get-field-position)
