#lang racket

(define rv_zksh-rd
  (make-immutable-hash
    '(
      (sm3p0 . 1)
      (sm3p1 . 1)
    )))
(define rv_zksh-rs1
  (make-immutable-hash
    '(
      (sm3p0 . 2)
      (sm3p1 . 2)
    )))

(define rv_zksh-fields '(rd rs1))

(define rv_zksh-param-count
  (make-immutable-hash
    '(
      (sm3p0 . 2)
      (sm3p1 . 2)
    )))

(define rv_zksh-operands
  (make-immutable-hash
    '(
      (sm3p0 . (rd rs1))
      (sm3p1 . (rd rs1))
    )))

(define rv_zksh-asm
  (make-immutable-hash
    '(
      (sm3p0 . "sm3p0 rd, rs1")
      (sm3p1 . "sm3p1 rd, rs1")
    )))

(define rv_zksh-operand-types
  (make-immutable-hash
    '(
      (sm3p0 . (reg reg))
      (sm3p1 . (reg reg))
    )))

(define rv_zksh-width 32)

;; ====== Helper functions ======

(define (rv_zksh-get-param-count mnemonic)
  (hash-ref rv_zksh-param-count mnemonic #f))

(define (rv_zksh-get-operands mnemonic)
  (hash-ref rv_zksh-operands mnemonic '()))

(define (rv_zksh-get-asm mnemonic)
  (hash-ref rv_zksh-asm mnemonic #f))

(define (rv_zksh-get-operand-types mnemonic)
  (hash-ref rv_zksh-operand-types mnemonic '()))

(define (rv_zksh-get-width) rv_zksh-width)

(define (rv_zksh-exists? mnemonic)
  (hash-has-key? rv_zksh-param-count mnemonic))

(define (rv_zksh-get-field-position mnemonic field)
  (case field
    [(rd) (hash-ref rv_zksh-rd mnemonic #f)]
    [(rs1) (hash-ref rv_zksh-rs1 mnemonic #f)]
    [else #f]))

(provide
  rv_zksh-rd
  rv_zksh-rs1
  rv_zksh-fields
  rv_zksh-param-count
  rv_zksh-operands
  rv_zksh-asm
  rv_zksh-operand-types
  rv_zksh-width
  rv_zksh-get-param-count
  rv_zksh-get-operands
  rv_zksh-get-asm
  rv_zksh-get-operand-types
  rv_zksh-get-width
  rv_zksh-exists?
  rv_zksh-get-field-position)
