#lang racket


(define rv_zihintntl-fields '())

(define rv_zihintntl-param-count (make-immutable-hash '()))

(define rv_zihintntl-operands (make-immutable-hash '()))

(define rv_zihintntl-asm (make-immutable-hash '()))

(define rv_zihintntl-operand-types (make-immutable-hash '()))

(define rv_zihintntl-width 32)

;; ====== Helper functions ======

(define (rv_zihintntl-get-param-count mnemonic)
  (hash-ref rv_zihintntl-param-count mnemonic #f))

(define (rv_zihintntl-get-operands mnemonic)
  (hash-ref rv_zihintntl-operands mnemonic '()))

(define (rv_zihintntl-get-asm mnemonic)
  (hash-ref rv_zihintntl-asm mnemonic #f))

(define (rv_zihintntl-get-operand-types mnemonic)
  (hash-ref rv_zihintntl-operand-types mnemonic '()))

(define (rv_zihintntl-get-width) rv_zihintntl-width)

(define (rv_zihintntl-exists? mnemonic)
  (hash-has-key? rv_zihintntl-param-count mnemonic))

(define (rv_zihintntl-get-field-position mnemonic field)
  (case field

    [else #f]))

(provide
  rv_zihintntl-fields
  rv_zihintntl-param-count
  rv_zihintntl-operands
  rv_zihintntl-asm
  rv_zihintntl-operand-types
  rv_zihintntl-width
  rv_zihintntl-get-param-count
  rv_zihintntl-get-operands
  rv_zihintntl-get-asm
  rv_zihintntl-get-operand-types
  rv_zihintntl-get-width
  rv_zihintntl-exists?
  rv_zihintntl-get-field-position)
