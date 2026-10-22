#lang racket


(define rv_c_zihintntl-fields '())

(define rv_c_zihintntl-param-count (make-immutable-hash '()))

(define rv_c_zihintntl-operands (make-immutable-hash '()))

(define rv_c_zihintntl-asm (make-immutable-hash '()))

(define rv_c_zihintntl-operand-types (make-immutable-hash '()))

(define rv_c_zihintntl-width 16)

;; ====== Helper functions ======

(define (rv_c_zihintntl-get-param-count mnemonic)
  (hash-ref rv_c_zihintntl-param-count mnemonic #f))

(define (rv_c_zihintntl-get-operands mnemonic)
  (hash-ref rv_c_zihintntl-operands mnemonic '()))

(define (rv_c_zihintntl-get-asm mnemonic)
  (hash-ref rv_c_zihintntl-asm mnemonic #f))

(define (rv_c_zihintntl-get-operand-types mnemonic)
  (hash-ref rv_c_zihintntl-operand-types mnemonic '()))

(define (rv_c_zihintntl-get-width) rv_c_zihintntl-width)

(define (rv_c_zihintntl-exists? mnemonic)
  (hash-has-key? rv_c_zihintntl-param-count mnemonic))

(define (rv_c_zihintntl-get-field-position mnemonic field)
  (case field

    [else #f]))

(provide
  rv_c_zihintntl-fields
  rv_c_zihintntl-param-count
  rv_c_zihintntl-operands
  rv_c_zihintntl-asm
  rv_c_zihintntl-operand-types
  rv_c_zihintntl-width
  rv_c_zihintntl-get-param-count
  rv_c_zihintntl-get-operands
  rv_c_zihintntl-get-asm
  rv_c_zihintntl-get-operand-types
  rv_c_zihintntl-get-width
  rv_c_zihintntl-exists?
  rv_c_zihintntl-get-field-position)
