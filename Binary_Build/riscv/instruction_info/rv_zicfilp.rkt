#lang racket


(define rv_zicfilp-fields '())

(define rv_zicfilp-param-count (make-immutable-hash '()))

(define rv_zicfilp-operands (make-immutable-hash '()))

(define rv_zicfilp-asm (make-immutable-hash '()))

(define rv_zicfilp-operand-types (make-immutable-hash '()))

(define rv_zicfilp-width 32)

;; ====== Helper functions ======

(define (rv_zicfilp-get-param-count mnemonic)
  (hash-ref rv_zicfilp-param-count mnemonic #f))

(define (rv_zicfilp-get-operands mnemonic)
  (hash-ref rv_zicfilp-operands mnemonic '()))

(define (rv_zicfilp-get-asm mnemonic)
  (hash-ref rv_zicfilp-asm mnemonic #f))

(define (rv_zicfilp-get-operand-types mnemonic)
  (hash-ref rv_zicfilp-operand-types mnemonic '()))

(define (rv_zicfilp-get-width) rv_zicfilp-width)

(define (rv_zicfilp-exists? mnemonic)
  (hash-has-key? rv_zicfilp-param-count mnemonic))

(define (rv_zicfilp-get-field-position mnemonic field)
  (case field

    [else #f]))

(provide
  rv_zicfilp-fields
  rv_zicfilp-param-count
  rv_zicfilp-operands
  rv_zicfilp-asm
  rv_zicfilp-operand-types
  rv_zicfilp-width
  rv_zicfilp-get-param-count
  rv_zicfilp-get-operands
  rv_zicfilp-get-asm
  rv_zicfilp-get-operand-types
  rv_zicfilp-get-width
  rv_zicfilp-exists?
  rv_zicfilp-get-field-position)
