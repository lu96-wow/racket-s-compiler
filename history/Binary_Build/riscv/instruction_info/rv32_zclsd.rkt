#lang racket


(define rv32_zclsd-fields '())

(define rv32_zclsd-param-count (make-immutable-hash '()))

(define rv32_zclsd-operands (make-immutable-hash '()))

(define rv32_zclsd-asm (make-immutable-hash '()))

(define rv32_zclsd-operand-types (make-immutable-hash '()))

(define rv32_zclsd-width 32)

;; ====== Helper functions ======

(define (rv32_zclsd-get-param-count mnemonic)
  (hash-ref rv32_zclsd-param-count mnemonic #f))

(define (rv32_zclsd-get-operands mnemonic)
  (hash-ref rv32_zclsd-operands mnemonic '()))

(define (rv32_zclsd-get-asm mnemonic)
  (hash-ref rv32_zclsd-asm mnemonic #f))

(define (rv32_zclsd-get-operand-types mnemonic)
  (hash-ref rv32_zclsd-operand-types mnemonic '()))

(define (rv32_zclsd-get-width) rv32_zclsd-width)

(define (rv32_zclsd-exists? mnemonic)
  (hash-has-key? rv32_zclsd-param-count mnemonic))

(define (rv32_zclsd-get-field-position mnemonic field)
  (case field

    [else #f]))

(provide
  rv32_zclsd-fields
  rv32_zclsd-param-count
  rv32_zclsd-operands
  rv32_zclsd-asm
  rv32_zclsd-operand-types
  rv32_zclsd-width
  rv32_zclsd-get-param-count
  rv32_zclsd-get-operands
  rv32_zclsd-get-asm
  rv32_zclsd-get-operand-types
  rv32_zclsd-get-width
  rv32_zclsd-exists?
  rv32_zclsd-get-field-position)
