#lang racket


(define rv_zks-fields '())

(define rv_zks-param-count (make-immutable-hash '()))

(define rv_zks-operands (make-immutable-hash '()))

(define rv_zks-asm (make-immutable-hash '()))

(define rv_zks-operand-types (make-immutable-hash '()))

(define rv_zks-width 32)

;; ====== Helper functions ======

(define (rv_zks-get-param-count mnemonic)
  (hash-ref rv_zks-param-count mnemonic #f))

(define (rv_zks-get-operands mnemonic)
  (hash-ref rv_zks-operands mnemonic '()))

(define (rv_zks-get-asm mnemonic)
  (hash-ref rv_zks-asm mnemonic #f))

(define (rv_zks-get-operand-types mnemonic)
  (hash-ref rv_zks-operand-types mnemonic '()))

(define (rv_zks-get-width) rv_zks-width)

(define (rv_zks-exists? mnemonic)
  (hash-has-key? rv_zks-param-count mnemonic))

(define (rv_zks-get-field-position mnemonic field)
  (case field

    [else #f]))

(provide
  rv_zks-fields
  rv_zks-param-count
  rv_zks-operands
  rv_zks-asm
  rv_zks-operand-types
  rv_zks-width
  rv_zks-get-param-count
  rv_zks-get-operands
  rv_zks-get-asm
  rv_zks-get-operand-types
  rv_zks-get-width
  rv_zks-exists?
  rv_zks-get-field-position)
