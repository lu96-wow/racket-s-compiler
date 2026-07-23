#lang racket


(define rv_zvknhb-fields '())

(define rv_zvknhb-param-count (make-immutable-hash '()))

(define rv_zvknhb-operands (make-immutable-hash '()))

(define rv_zvknhb-asm (make-immutable-hash '()))

(define rv_zvknhb-operand-types (make-immutable-hash '()))

(define rv_zvknhb-width 32)

;; ====== Helper functions ======

(define (rv_zvknhb-get-param-count mnemonic)
  (hash-ref rv_zvknhb-param-count mnemonic #f))

(define (rv_zvknhb-get-operands mnemonic)
  (hash-ref rv_zvknhb-operands mnemonic '()))

(define (rv_zvknhb-get-asm mnemonic)
  (hash-ref rv_zvknhb-asm mnemonic #f))

(define (rv_zvknhb-get-operand-types mnemonic)
  (hash-ref rv_zvknhb-operand-types mnemonic '()))

(define (rv_zvknhb-get-width) rv_zvknhb-width)

(define (rv_zvknhb-exists? mnemonic)
  (hash-has-key? rv_zvknhb-param-count mnemonic))

(define (rv_zvknhb-get-field-position mnemonic field)
  (case field

    [else #f]))

(provide
  rv_zvknhb-fields
  rv_zvknhb-param-count
  rv_zvknhb-operands
  rv_zvknhb-asm
  rv_zvknhb-operand-types
  rv_zvknhb-width
  rv_zvknhb-get-param-count
  rv_zvknhb-get-operands
  rv_zvknhb-get-asm
  rv_zvknhb-get-operand-types
  rv_zvknhb-get-width
  rv_zvknhb-exists?
  rv_zvknhb-get-field-position)
