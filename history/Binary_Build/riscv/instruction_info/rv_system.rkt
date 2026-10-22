#lang racket


(define rv_system-fields '())

(define rv_system-param-count
  (make-immutable-hash
    '(
      (mret . 0)
      (wfi . 0)
    )))

(define rv_system-operands
  (make-immutable-hash
    '(
      (mret . ())
      (wfi . ())
    )))

(define rv_system-asm
  (make-immutable-hash
    '(
      (mret . "mret")
      (wfi . "wfi")
    )))

(define rv_system-operand-types
  (make-immutable-hash
    '(
      (mret . ())
      (wfi . ())
    )))

(define rv_system-width 32)

;; ====== Helper functions ======

(define (rv_system-get-param-count mnemonic)
  (hash-ref rv_system-param-count mnemonic #f))

(define (rv_system-get-operands mnemonic)
  (hash-ref rv_system-operands mnemonic '()))

(define (rv_system-get-asm mnemonic)
  (hash-ref rv_system-asm mnemonic #f))

(define (rv_system-get-operand-types mnemonic)
  (hash-ref rv_system-operand-types mnemonic '()))

(define (rv_system-get-width) rv_system-width)

(define (rv_system-exists? mnemonic)
  (hash-has-key? rv_system-param-count mnemonic))

(define (rv_system-get-field-position mnemonic field)
  (case field

    [else #f]))

(provide
  rv_system-fields
  rv_system-param-count
  rv_system-operands
  rv_system-asm
  rv_system-operand-types
  rv_system-width
  rv_system-get-param-count
  rv_system-get-operands
  rv_system-get-asm
  rv_system-get-operand-types
  rv_system-get-width
  rv_system-exists?
  rv_system-get-field-position)
