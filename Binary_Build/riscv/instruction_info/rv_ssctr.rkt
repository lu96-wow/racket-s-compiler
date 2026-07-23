#lang racket


(define rv_ssctr-fields '())

(define rv_ssctr-param-count
  (make-immutable-hash
    '(
      (sctrclr . 0)
    )))

(define rv_ssctr-operands
  (make-immutable-hash
    '(
      (sctrclr . ())
    )))

(define rv_ssctr-asm
  (make-immutable-hash
    '(
      (sctrclr . "sctrclr")
    )))

(define rv_ssctr-operand-types
  (make-immutable-hash
    '(
      (sctrclr . ())
    )))

(define rv_ssctr-width 32)

;; ====== Helper functions ======

(define (rv_ssctr-get-param-count mnemonic)
  (hash-ref rv_ssctr-param-count mnemonic #f))

(define (rv_ssctr-get-operands mnemonic)
  (hash-ref rv_ssctr-operands mnemonic '()))

(define (rv_ssctr-get-asm mnemonic)
  (hash-ref rv_ssctr-asm mnemonic #f))

(define (rv_ssctr-get-operand-types mnemonic)
  (hash-ref rv_ssctr-operand-types mnemonic '()))

(define (rv_ssctr-get-width) rv_ssctr-width)

(define (rv_ssctr-exists? mnemonic)
  (hash-has-key? rv_ssctr-param-count mnemonic))

(define (rv_ssctr-get-field-position mnemonic field)
  (case field

    [else #f]))

(provide
  rv_ssctr-fields
  rv_ssctr-param-count
  rv_ssctr-operands
  rv_ssctr-asm
  rv_ssctr-operand-types
  rv_ssctr-width
  rv_ssctr-get-param-count
  rv_ssctr-get-operands
  rv_ssctr-get-asm
  rv_ssctr-get-operand-types
  rv_ssctr-get-width
  rv_ssctr-exists?
  rv_ssctr-get-field-position)
