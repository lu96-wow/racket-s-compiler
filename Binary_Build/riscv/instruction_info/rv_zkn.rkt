#lang racket


(define rv_zkn-fields '())

(define rv_zkn-param-count (make-immutable-hash '()))

(define rv_zkn-operands (make-immutable-hash '()))

(define rv_zkn-asm (make-immutable-hash '()))

(define rv_zkn-operand-types (make-immutable-hash '()))

(define rv_zkn-width 32)

;; ====== Helper functions ======

(define (rv_zkn-get-param-count mnemonic)
  (hash-ref rv_zkn-param-count mnemonic #f))

(define (rv_zkn-get-operands mnemonic)
  (hash-ref rv_zkn-operands mnemonic '()))

(define (rv_zkn-get-asm mnemonic)
  (hash-ref rv_zkn-asm mnemonic #f))

(define (rv_zkn-get-operand-types mnemonic)
  (hash-ref rv_zkn-operand-types mnemonic '()))

(define (rv_zkn-get-width) rv_zkn-width)

(define (rv_zkn-exists? mnemonic)
  (hash-has-key? rv_zkn-param-count mnemonic))

(define (rv_zkn-get-field-position mnemonic field)
  (case field

    [else #f]))

(provide
  rv_zkn-fields
  rv_zkn-param-count
  rv_zkn-operands
  rv_zkn-asm
  rv_zkn-operand-types
  rv_zkn-width
  rv_zkn-get-param-count
  rv_zkn-get-operands
  rv_zkn-get-asm
  rv_zkn-get-operand-types
  rv_zkn-get-width
  rv_zkn-exists?
  rv_zkn-get-field-position)
