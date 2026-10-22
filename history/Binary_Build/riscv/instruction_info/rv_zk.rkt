#lang racket


(define rv_zk-fields '())

(define rv_zk-param-count (make-immutable-hash '()))

(define rv_zk-operands (make-immutable-hash '()))

(define rv_zk-asm (make-immutable-hash '()))

(define rv_zk-operand-types (make-immutable-hash '()))

(define rv_zk-width 32)

;; ====== Helper functions ======

(define (rv_zk-get-param-count mnemonic)
  (hash-ref rv_zk-param-count mnemonic #f))

(define (rv_zk-get-operands mnemonic)
  (hash-ref rv_zk-operands mnemonic '()))

(define (rv_zk-get-asm mnemonic)
  (hash-ref rv_zk-asm mnemonic #f))

(define (rv_zk-get-operand-types mnemonic)
  (hash-ref rv_zk-operand-types mnemonic '()))

(define (rv_zk-get-width) rv_zk-width)

(define (rv_zk-exists? mnemonic)
  (hash-has-key? rv_zk-param-count mnemonic))

(define (rv_zk-get-field-position mnemonic field)
  (case field

    [else #f]))

(provide
  rv_zk-fields
  rv_zk-param-count
  rv_zk-operands
  rv_zk-asm
  rv_zk-operand-types
  rv_zk-width
  rv_zk-get-param-count
  rv_zk-get-operands
  rv_zk-get-asm
  rv_zk-get-operand-types
  rv_zk-get-width
  rv_zk-exists?
  rv_zk-get-field-position)
