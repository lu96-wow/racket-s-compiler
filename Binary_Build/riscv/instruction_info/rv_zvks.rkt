#lang racket


(define rv_zvks-fields '())

(define rv_zvks-param-count (make-immutable-hash '()))

(define rv_zvks-operands (make-immutable-hash '()))

(define rv_zvks-asm (make-immutable-hash '()))

(define rv_zvks-operand-types (make-immutable-hash '()))

(define rv_zvks-width 32)

;; ====== Helper functions ======

(define (rv_zvks-get-param-count mnemonic)
  (hash-ref rv_zvks-param-count mnemonic #f))

(define (rv_zvks-get-operands mnemonic)
  (hash-ref rv_zvks-operands mnemonic '()))

(define (rv_zvks-get-asm mnemonic)
  (hash-ref rv_zvks-asm mnemonic #f))

(define (rv_zvks-get-operand-types mnemonic)
  (hash-ref rv_zvks-operand-types mnemonic '()))

(define (rv_zvks-get-width) rv_zvks-width)

(define (rv_zvks-exists? mnemonic)
  (hash-has-key? rv_zvks-param-count mnemonic))

(define (rv_zvks-get-field-position mnemonic field)
  (case field

    [else #f]))

(provide
  rv_zvks-fields
  rv_zvks-param-count
  rv_zvks-operands
  rv_zvks-asm
  rv_zvks-operand-types
  rv_zvks-width
  rv_zvks-get-param-count
  rv_zvks-get-operands
  rv_zvks-get-asm
  rv_zvks-get-operand-types
  rv_zvks-get-width
  rv_zvks-exists?
  rv_zvks-get-field-position)
