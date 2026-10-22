#lang racket


(define rv_zawrs-fields '())

(define rv_zawrs-param-count
  (make-immutable-hash
    '(
      (wrs.nto . 0)
      (wrs.sto . 0)
    )))

(define rv_zawrs-operands
  (make-immutable-hash
    '(
      (wrs.nto . ())
      (wrs.sto . ())
    )))

(define rv_zawrs-asm
  (make-immutable-hash
    '(
      (wrs.nto . "wrs.nto")
      (wrs.sto . "wrs.sto")
    )))

(define rv_zawrs-operand-types
  (make-immutable-hash
    '(
      (wrs.nto . ())
      (wrs.sto . ())
    )))

(define rv_zawrs-width 32)

;; ====== Helper functions ======

(define (rv_zawrs-get-param-count mnemonic)
  (hash-ref rv_zawrs-param-count mnemonic #f))

(define (rv_zawrs-get-operands mnemonic)
  (hash-ref rv_zawrs-operands mnemonic '()))

(define (rv_zawrs-get-asm mnemonic)
  (hash-ref rv_zawrs-asm mnemonic #f))

(define (rv_zawrs-get-operand-types mnemonic)
  (hash-ref rv_zawrs-operand-types mnemonic '()))

(define (rv_zawrs-get-width) rv_zawrs-width)

(define (rv_zawrs-exists? mnemonic)
  (hash-has-key? rv_zawrs-param-count mnemonic))

(define (rv_zawrs-get-field-position mnemonic field)
  (case field

    [else #f]))

(provide
  rv_zawrs-fields
  rv_zawrs-param-count
  rv_zawrs-operands
  rv_zawrs-asm
  rv_zawrs-operand-types
  rv_zawrs-width
  rv_zawrs-get-param-count
  rv_zawrs-get-operands
  rv_zawrs-get-asm
  rv_zawrs-get-operand-types
  rv_zawrs-get-width
  rv_zawrs-exists?
  rv_zawrs-get-field-position)
