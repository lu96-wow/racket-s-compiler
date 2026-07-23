#lang racket

(define rv64_zcb-rd_rs1_p
  (make-immutable-hash
    '(
      (c.zext.w . 1)
    )))

(define rv64_zcb-fields '(rd_rs1_p))

(define rv64_zcb-param-count
  (make-immutable-hash
    '(
      (c.zext.w . 1)
    )))

(define rv64_zcb-operands
  (make-immutable-hash
    '(
      (c.zext.w . (rd_rs1_p))
    )))

(define rv64_zcb-asm
  (make-immutable-hash
    '(
      (c.zext.w . "c.zext.w rd_rs1_p")
    )))

(define rv64_zcb-operand-types
  (make-immutable-hash
    '(
      (c.zext.w . (reg))
    )))

(define rv64_zcb-width 32)

;; ====== Helper functions ======

(define (rv64_zcb-get-param-count mnemonic)
  (hash-ref rv64_zcb-param-count mnemonic #f))

(define (rv64_zcb-get-operands mnemonic)
  (hash-ref rv64_zcb-operands mnemonic '()))

(define (rv64_zcb-get-asm mnemonic)
  (hash-ref rv64_zcb-asm mnemonic #f))

(define (rv64_zcb-get-operand-types mnemonic)
  (hash-ref rv64_zcb-operand-types mnemonic '()))

(define (rv64_zcb-get-width) rv64_zcb-width)

(define (rv64_zcb-exists? mnemonic)
  (hash-has-key? rv64_zcb-param-count mnemonic))

(define (rv64_zcb-get-field-position mnemonic field)
  (case field
    [(rd_rs1_p) (hash-ref rv64_zcb-rd_rs1_p mnemonic #f)]
    [else #f]))

(provide
  rv64_zcb-rd_rs1_p
  rv64_zcb-fields
  rv64_zcb-param-count
  rv64_zcb-operands
  rv64_zcb-asm
  rv64_zcb-operand-types
  rv64_zcb-width
  rv64_zcb-get-param-count
  rv64_zcb-get-operands
  rv64_zcb-get-asm
  rv64_zcb-get-operand-types
  rv64_zcb-get-width
  rv64_zcb-exists?
  rv64_zcb-get-field-position)
