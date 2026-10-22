#lang racket

(define rv_zcmop-c_mop_t
  (make-immutable-hash
    '(
      (c.mop.N . 1)
    )))

(define rv_zcmop-fields '(c_mop_t))

(define rv_zcmop-param-count
  (make-immutable-hash
    '(
      (c.mop.N . 1)
    )))

(define rv_zcmop-operands
  (make-immutable-hash
    '(
      (c.mop.N . (c_mop_t))
    )))

(define rv_zcmop-asm
  (make-immutable-hash
    '(
      (c.mop.N . "c.mop.N c_mop_t")
    )))

(define rv_zcmop-operand-types
  (make-immutable-hash
    '(
      (c.mop.N . (imm))
    )))

(define rv_zcmop-width 16)

;; ====== Helper functions ======

(define (rv_zcmop-get-param-count mnemonic)
  (hash-ref rv_zcmop-param-count mnemonic #f))

(define (rv_zcmop-get-operands mnemonic)
  (hash-ref rv_zcmop-operands mnemonic '()))

(define (rv_zcmop-get-asm mnemonic)
  (hash-ref rv_zcmop-asm mnemonic #f))

(define (rv_zcmop-get-operand-types mnemonic)
  (hash-ref rv_zcmop-operand-types mnemonic '()))

(define (rv_zcmop-get-width) rv_zcmop-width)

(define (rv_zcmop-exists? mnemonic)
  (hash-has-key? rv_zcmop-param-count mnemonic))

(define (rv_zcmop-get-field-position mnemonic field)
  (case field
    [(c_mop_t) (hash-ref rv_zcmop-c_mop_t mnemonic #f)]
    [else #f]))

(provide
  rv_zcmop-c_mop_t
  rv_zcmop-fields
  rv_zcmop-param-count
  rv_zcmop-operands
  rv_zcmop-asm
  rv_zcmop-operand-types
  rv_zcmop-width
  rv_zcmop-get-param-count
  rv_zcmop-get-operands
  rv_zcmop-get-asm
  rv_zcmop-get-operand-types
  rv_zcmop-get-width
  rv_zcmop-exists?
  rv_zcmop-get-field-position)
