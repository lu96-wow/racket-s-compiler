#lang racket


(define rv_c_zicfiss-fields '())

(define rv_c_zicfiss-param-count (make-immutable-hash '()))

(define rv_c_zicfiss-operands (make-immutable-hash '()))

(define rv_c_zicfiss-asm (make-immutable-hash '()))

(define rv_c_zicfiss-operand-types (make-immutable-hash '()))

(define rv_c_zicfiss-width 16)

;; ====== Helper functions ======

(define (rv_c_zicfiss-get-param-count mnemonic)
  (hash-ref rv_c_zicfiss-param-count mnemonic #f))

(define (rv_c_zicfiss-get-operands mnemonic)
  (hash-ref rv_c_zicfiss-operands mnemonic '()))

(define (rv_c_zicfiss-get-asm mnemonic)
  (hash-ref rv_c_zicfiss-asm mnemonic #f))

(define (rv_c_zicfiss-get-operand-types mnemonic)
  (hash-ref rv_c_zicfiss-operand-types mnemonic '()))

(define (rv_c_zicfiss-get-width) rv_c_zicfiss-width)

(define (rv_c_zicfiss-exists? mnemonic)
  (hash-has-key? rv_c_zicfiss-param-count mnemonic))

(define (rv_c_zicfiss-get-field-position mnemonic field)
  (case field

    [else #f]))

(provide
  rv_c_zicfiss-fields
  rv_c_zicfiss-param-count
  rv_c_zicfiss-operands
  rv_c_zicfiss-asm
  rv_c_zicfiss-operand-types
  rv_c_zicfiss-width
  rv_c_zicfiss-get-param-count
  rv_c_zicfiss-get-operands
  rv_c_zicfiss-get-asm
  rv_c_zicfiss-get-operand-types
  rv_c_zicfiss-get-width
  rv_c_zicfiss-exists?
  rv_c_zicfiss-get-field-position)
