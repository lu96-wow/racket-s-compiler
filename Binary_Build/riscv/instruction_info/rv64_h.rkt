#lang racket

(define rv64_h-rd
  (make-immutable-hash
    '(
      (hlv.wu . 1)
      (hlv.d . 1)
    )))
(define rv64_h-rs1
  (make-immutable-hash
    '(
      (hlv.wu . 2)
      (hlv.d . 2)
      (hsv.d . 1)
    )))
(define rv64_h-rs2
  (make-immutable-hash
    '(
      (hsv.d . 2)
    )))

(define rv64_h-fields '(rd rs1 rs2))

(define rv64_h-param-count
  (make-immutable-hash
    '(
      (hlv.wu . 2)
      (hlv.d . 2)
      (hsv.d . 2)
    )))

(define rv64_h-operands
  (make-immutable-hash
    '(
      (hlv.wu . (rd rs1))
      (hlv.d . (rd rs1))
      (hsv.d . (rs1 rs2))
    )))

(define rv64_h-asm
  (make-immutable-hash
    '(
      (hlv.wu . "hlv.wu rd, rs1")
      (hlv.d . "hlv.d rd, rs1")
      (hsv.d . "hsv.d rs1, rs2")
    )))

(define rv64_h-operand-types
  (make-immutable-hash
    '(
      (hlv.wu . (reg reg))
      (hlv.d . (reg reg))
      (hsv.d . (reg reg))
    )))

(define rv64_h-width 32)

;; ====== Helper functions ======

(define (rv64_h-get-param-count mnemonic)
  (hash-ref rv64_h-param-count mnemonic #f))

(define (rv64_h-get-operands mnemonic)
  (hash-ref rv64_h-operands mnemonic '()))

(define (rv64_h-get-asm mnemonic)
  (hash-ref rv64_h-asm mnemonic #f))

(define (rv64_h-get-operand-types mnemonic)
  (hash-ref rv64_h-operand-types mnemonic '()))

(define (rv64_h-get-width) rv64_h-width)

(define (rv64_h-exists? mnemonic)
  (hash-has-key? rv64_h-param-count mnemonic))

(define (rv64_h-get-field-position mnemonic field)
  (case field
    [(rd) (hash-ref rv64_h-rd mnemonic #f)]
    [(rs1) (hash-ref rv64_h-rs1 mnemonic #f)]
    [(rs2) (hash-ref rv64_h-rs2 mnemonic #f)]
    [else #f]))

(provide
  rv64_h-rd
  rv64_h-rs1
  rv64_h-rs2
  rv64_h-fields
  rv64_h-param-count
  rv64_h-operands
  rv64_h-asm
  rv64_h-operand-types
  rv64_h-width
  rv64_h-get-param-count
  rv64_h-get-operands
  rv64_h-get-asm
  rv64_h-get-operand-types
  rv64_h-get-width
  rv64_h-exists?
  rv64_h-get-field-position)
