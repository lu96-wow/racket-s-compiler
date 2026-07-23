#lang racket


(define rv_zbkc-fields '())

(define rv_zbkc-param-count (make-immutable-hash '()))

(define rv_zbkc-operands (make-immutable-hash '()))

(define rv_zbkc-asm (make-immutable-hash '()))

(define rv_zbkc-operand-types (make-immutable-hash '()))

(define rv_zbkc-width 32)

;; ====== Helper functions ======

(define (rv_zbkc-get-param-count mnemonic)
  (hash-ref rv_zbkc-param-count mnemonic #f))

(define (rv_zbkc-get-operands mnemonic)
  (hash-ref rv_zbkc-operands mnemonic '()))

(define (rv_zbkc-get-asm mnemonic)
  (hash-ref rv_zbkc-asm mnemonic #f))

(define (rv_zbkc-get-operand-types mnemonic)
  (hash-ref rv_zbkc-operand-types mnemonic '()))

(define (rv_zbkc-get-width) rv_zbkc-width)

(define (rv_zbkc-exists? mnemonic)
  (hash-has-key? rv_zbkc-param-count mnemonic))

(define (rv_zbkc-get-field-position mnemonic field)
  (case field

    [else #f]))

(provide
  rv_zbkc-fields
  rv_zbkc-param-count
  rv_zbkc-operands
  rv_zbkc-asm
  rv_zbkc-operand-types
  rv_zbkc-width
  rv_zbkc-get-param-count
  rv_zbkc-get-operands
  rv_zbkc-get-asm
  rv_zbkc-get-operand-types
  rv_zbkc-get-width
  rv_zbkc-exists?
  rv_zbkc-get-field-position)
