#lang racket


(define rv_v_aliases-fields '())

(define rv_v_aliases-param-count (make-immutable-hash '()))

(define rv_v_aliases-operands (make-immutable-hash '()))

(define rv_v_aliases-asm (make-immutable-hash '()))

(define rv_v_aliases-operand-types (make-immutable-hash '()))

(define rv_v_aliases-width 32)

;; ====== Helper functions ======

(define (rv_v_aliases-get-param-count mnemonic)
  (hash-ref rv_v_aliases-param-count mnemonic #f))

(define (rv_v_aliases-get-operands mnemonic)
  (hash-ref rv_v_aliases-operands mnemonic '()))

(define (rv_v_aliases-get-asm mnemonic)
  (hash-ref rv_v_aliases-asm mnemonic #f))

(define (rv_v_aliases-get-operand-types mnemonic)
  (hash-ref rv_v_aliases-operand-types mnemonic '()))

(define (rv_v_aliases-get-width) rv_v_aliases-width)

(define (rv_v_aliases-exists? mnemonic)
  (hash-has-key? rv_v_aliases-param-count mnemonic))

(define (rv_v_aliases-get-field-position mnemonic field)
  (case field

    [else #f]))

(provide
  rv_v_aliases-fields
  rv_v_aliases-param-count
  rv_v_aliases-operands
  rv_v_aliases-asm
  rv_v_aliases-operand-types
  rv_v_aliases-width
  rv_v_aliases-get-param-count
  rv_v_aliases-get-operands
  rv_v_aliases-get-asm
  rv_v_aliases-get-operand-types
  rv_v_aliases-get-width
  rv_v_aliases-exists?
  rv_v_aliases-get-field-position)
