#lang racket

(define rv_zba-rd
  (make-immutable-hash
    '(
      (sh1add . 1)
      (sh2add . 1)
      (sh3add . 1)
    )))
(define rv_zba-rs1
  (make-immutable-hash
    '(
      (sh1add . 2)
      (sh2add . 2)
      (sh3add . 2)
    )))
(define rv_zba-rs2
  (make-immutable-hash
    '(
      (sh1add . 3)
      (sh2add . 3)
      (sh3add . 3)
    )))

(define rv_zba-fields '(rd rs1 rs2))

(define rv_zba-param-count
  (make-immutable-hash
    '(
      (sh1add . 3)
      (sh2add . 3)
      (sh3add . 3)
    )))

(define rv_zba-operands
  (make-immutable-hash
    '(
      (sh1add . (rd rs1 rs2))
      (sh2add . (rd rs1 rs2))
      (sh3add . (rd rs1 rs2))
    )))

(define rv_zba-asm
  (make-immutable-hash
    '(
      (sh1add . "sh1add rd, rs1, rs2")
      (sh2add . "sh2add rd, rs1, rs2")
      (sh3add . "sh3add rd, rs1, rs2")
    )))

(define rv_zba-operand-types
  (make-immutable-hash
    '(
      (sh1add . (reg reg reg))
      (sh2add . (reg reg reg))
      (sh3add . (reg reg reg))
    )))

(define rv_zba-width 32)

;; ====== Helper functions ======

(define (rv_zba-get-param-count mnemonic)
  (hash-ref rv_zba-param-count mnemonic #f))

(define (rv_zba-get-operands mnemonic)
  (hash-ref rv_zba-operands mnemonic '()))

(define (rv_zba-get-asm mnemonic)
  (hash-ref rv_zba-asm mnemonic #f))

(define (rv_zba-get-operand-types mnemonic)
  (hash-ref rv_zba-operand-types mnemonic '()))

(define (rv_zba-get-width) rv_zba-width)

(define (rv_zba-exists? mnemonic)
  (hash-has-key? rv_zba-param-count mnemonic))

(define (rv_zba-get-field-position mnemonic field)
  (case field
    [(rd) (hash-ref rv_zba-rd mnemonic #f)]
    [(rs1) (hash-ref rv_zba-rs1 mnemonic #f)]
    [(rs2) (hash-ref rv_zba-rs2 mnemonic #f)]
    [else #f]))

(provide
  rv_zba-rd
  rv_zba-rs1
  rv_zba-rs2
  rv_zba-fields
  rv_zba-param-count
  rv_zba-operands
  rv_zba-asm
  rv_zba-operand-types
  rv_zba-width
  rv_zba-get-param-count
  rv_zba-get-operands
  rv_zba-get-asm
  rv_zba-get-operand-types
  rv_zba-get-width
  rv_zba-exists?
  rv_zba-get-field-position)
