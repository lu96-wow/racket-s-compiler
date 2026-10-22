#lang racket


(define rv_sdext-fields '())

(define rv_sdext-param-count
  (make-immutable-hash
    '(
      (dret . 0)
    )))

(define rv_sdext-operands
  (make-immutable-hash
    '(
      (dret . ())
    )))

(define rv_sdext-asm
  (make-immutable-hash
    '(
      (dret . "dret")
    )))

(define rv_sdext-operand-types
  (make-immutable-hash
    '(
      (dret . ())
    )))

(define rv_sdext-width 32)

;; ====== Helper functions ======

(define (rv_sdext-get-param-count mnemonic)
  (hash-ref rv_sdext-param-count mnemonic #f))

(define (rv_sdext-get-operands mnemonic)
  (hash-ref rv_sdext-operands mnemonic '()))

(define (rv_sdext-get-asm mnemonic)
  (hash-ref rv_sdext-asm mnemonic #f))

(define (rv_sdext-get-operand-types mnemonic)
  (hash-ref rv_sdext-operand-types mnemonic '()))

(define (rv_sdext-get-width) rv_sdext-width)

(define (rv_sdext-exists? mnemonic)
  (hash-has-key? rv_sdext-param-count mnemonic))

(define (rv_sdext-get-field-position mnemonic field)
  (case field

    [else #f]))

(provide
  rv_sdext-fields
  rv_sdext-param-count
  rv_sdext-operands
  rv_sdext-asm
  rv_sdext-operand-types
  rv_sdext-width
  rv_sdext-get-param-count
  rv_sdext-get-operands
  rv_sdext-get-asm
  rv_sdext-get-operand-types
  rv_sdext-get-width
  rv_sdext-exists?
  rv_sdext-get-field-position)
