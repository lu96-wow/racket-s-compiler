#lang racket


(define rv_zicntr-fields '())

(define rv_zicntr-param-count (make-immutable-hash '()))

(define rv_zicntr-operands (make-immutable-hash '()))

(define rv_zicntr-asm (make-immutable-hash '()))

(define rv_zicntr-operand-types (make-immutable-hash '()))

(define rv_zicntr-width 32)

;; ====== Helper functions ======

(define (rv_zicntr-get-param-count mnemonic)
  (hash-ref rv_zicntr-param-count mnemonic #f))

(define (rv_zicntr-get-operands mnemonic)
  (hash-ref rv_zicntr-operands mnemonic '()))

(define (rv_zicntr-get-asm mnemonic)
  (hash-ref rv_zicntr-asm mnemonic #f))

(define (rv_zicntr-get-operand-types mnemonic)
  (hash-ref rv_zicntr-operand-types mnemonic '()))

(define (rv_zicntr-get-width) rv_zicntr-width)

(define (rv_zicntr-exists? mnemonic)
  (hash-has-key? rv_zicntr-param-count mnemonic))

(define (rv_zicntr-get-field-position mnemonic field)
  (case field

    [else #f]))

(provide
  rv_zicntr-fields
  rv_zicntr-param-count
  rv_zicntr-operands
  rv_zicntr-asm
  rv_zicntr-operand-types
  rv_zicntr-width
  rv_zicntr-get-param-count
  rv_zicntr-get-operands
  rv_zicntr-get-asm
  rv_zicntr-get-operand-types
  rv_zicntr-get-width
  rv_zicntr-exists?
  rv_zicntr-get-field-position)
