#lang racket

(define rv_zcmt-c_index
  (make-immutable-hash
    '(
      (cm.jalt . 1)
    )))

(define rv_zcmt-fields '(c_index))

(define rv_zcmt-param-count
  (make-immutable-hash
    '(
      (cm.jalt . 1)
    )))

(define rv_zcmt-operands
  (make-immutable-hash
    '(
      (cm.jalt . (c_index))
    )))

(define rv_zcmt-asm
  (make-immutable-hash
    '(
      (cm.jalt . "cm.jalt c_index")
    )))

(define rv_zcmt-operand-types
  (make-immutable-hash
    '(
      (cm.jalt . (imm))
    )))

(define rv_zcmt-width 16)

;; ====== Helper functions ======

(define (rv_zcmt-get-param-count mnemonic)
  (hash-ref rv_zcmt-param-count mnemonic #f))

(define (rv_zcmt-get-operands mnemonic)
  (hash-ref rv_zcmt-operands mnemonic '()))

(define (rv_zcmt-get-asm mnemonic)
  (hash-ref rv_zcmt-asm mnemonic #f))

(define (rv_zcmt-get-operand-types mnemonic)
  (hash-ref rv_zcmt-operand-types mnemonic '()))

(define (rv_zcmt-get-width) rv_zcmt-width)

(define (rv_zcmt-exists? mnemonic)
  (hash-has-key? rv_zcmt-param-count mnemonic))

(define (rv_zcmt-get-field-position mnemonic field)
  (case field
    [(c_index) (hash-ref rv_zcmt-c_index mnemonic #f)]
    [else #f]))

(provide
  rv_zcmt-c_index
  rv_zcmt-fields
  rv_zcmt-param-count
  rv_zcmt-operands
  rv_zcmt-asm
  rv_zcmt-operand-types
  rv_zcmt-width
  rv_zcmt-get-param-count
  rv_zcmt-get-operands
  rv_zcmt-get-asm
  rv_zcmt-get-operand-types
  rv_zcmt-get-width
  rv_zcmt-exists?
  rv_zcmt-get-field-position)
