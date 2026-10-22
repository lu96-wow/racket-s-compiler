#lang racket


(define rv_zvkn-fields '())

(define rv_zvkn-param-count (make-immutable-hash '()))

(define rv_zvkn-operands (make-immutable-hash '()))

(define rv_zvkn-asm (make-immutable-hash '()))

(define rv_zvkn-operand-types (make-immutable-hash '()))

(define rv_zvkn-width 32)

;; ====== Helper functions ======

(define (rv_zvkn-get-param-count mnemonic)
  (hash-ref rv_zvkn-param-count mnemonic #f))

(define (rv_zvkn-get-operands mnemonic)
  (hash-ref rv_zvkn-operands mnemonic '()))

(define (rv_zvkn-get-asm mnemonic)
  (hash-ref rv_zvkn-asm mnemonic #f))

(define (rv_zvkn-get-operand-types mnemonic)
  (hash-ref rv_zvkn-operand-types mnemonic '()))

(define (rv_zvkn-get-width) rv_zvkn-width)

(define (rv_zvkn-exists? mnemonic)
  (hash-has-key? rv_zvkn-param-count mnemonic))

(define (rv_zvkn-get-field-position mnemonic field)
  (case field

    [else #f]))

(provide
  rv_zvkn-fields
  rv_zvkn-param-count
  rv_zvkn-operands
  rv_zvkn-asm
  rv_zvkn-operand-types
  rv_zvkn-width
  rv_zvkn-get-param-count
  rv_zvkn-get-operands
  rv_zvkn-get-asm
  rv_zvkn-get-operand-types
  rv_zvkn-get-width
  rv_zvkn-exists?
  rv_zvkn-get-field-position)
