#lang racket


(define rv32_zicntr-fields '())

(define rv32_zicntr-param-count (make-immutable-hash '()))

(define rv32_zicntr-operands (make-immutable-hash '()))

(define rv32_zicntr-asm (make-immutable-hash '()))

(define rv32_zicntr-operand-types (make-immutable-hash '()))

(define rv32_zicntr-width 32)

;; ====== Helper functions ======

(define (rv32_zicntr-get-param-count mnemonic)
  (hash-ref rv32_zicntr-param-count mnemonic #f))

(define (rv32_zicntr-get-operands mnemonic)
  (hash-ref rv32_zicntr-operands mnemonic '()))

(define (rv32_zicntr-get-asm mnemonic)
  (hash-ref rv32_zicntr-asm mnemonic #f))

(define (rv32_zicntr-get-operand-types mnemonic)
  (hash-ref rv32_zicntr-operand-types mnemonic '()))

(define (rv32_zicntr-get-width) rv32_zicntr-width)

(define (rv32_zicntr-exists? mnemonic)
  (hash-has-key? rv32_zicntr-param-count mnemonic))

(define (rv32_zicntr-get-field-position mnemonic field)
  (case field

    [else #f]))

(provide
  rv32_zicntr-fields
  rv32_zicntr-param-count
  rv32_zicntr-operands
  rv32_zicntr-asm
  rv32_zicntr-operand-types
  rv32_zicntr-width
  rv32_zicntr-get-param-count
  rv32_zicntr-get-operands
  rv32_zicntr-get-asm
  rv32_zicntr-get-operand-types
  rv32_zicntr-get-width
  rv32_zicntr-exists?
  rv32_zicntr-get-field-position)
