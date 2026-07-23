#lang racket


(define rv_smrnmi-fields '())

(define rv_smrnmi-param-count
  (make-immutable-hash
    '(
      (mnret . 0)
    )))

(define rv_smrnmi-operands
  (make-immutable-hash
    '(
      (mnret . ())
    )))

(define rv_smrnmi-asm
  (make-immutable-hash
    '(
      (mnret . "mnret")
    )))

(define rv_smrnmi-operand-types
  (make-immutable-hash
    '(
      (mnret . ())
    )))

(define rv_smrnmi-width 32)

;; ====== Helper functions ======

(define (rv_smrnmi-get-param-count mnemonic)
  (hash-ref rv_smrnmi-param-count mnemonic #f))

(define (rv_smrnmi-get-operands mnemonic)
  (hash-ref rv_smrnmi-operands mnemonic '()))

(define (rv_smrnmi-get-asm mnemonic)
  (hash-ref rv_smrnmi-asm mnemonic #f))

(define (rv_smrnmi-get-operand-types mnemonic)
  (hash-ref rv_smrnmi-operand-types mnemonic '()))

(define (rv_smrnmi-get-width) rv_smrnmi-width)

(define (rv_smrnmi-exists? mnemonic)
  (hash-has-key? rv_smrnmi-param-count mnemonic))

(define (rv_smrnmi-get-field-position mnemonic field)
  (case field

    [else #f]))

(provide
  rv_smrnmi-fields
  rv_smrnmi-param-count
  rv_smrnmi-operands
  rv_smrnmi-asm
  rv_smrnmi-operand-types
  rv_smrnmi-width
  rv_smrnmi-get-param-count
  rv_smrnmi-get-operands
  rv_smrnmi-get-asm
  rv_smrnmi-get-operand-types
  rv_smrnmi-get-width
  rv_smrnmi-exists?
  rv_smrnmi-get-field-position)
