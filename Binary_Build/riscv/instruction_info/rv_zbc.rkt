#lang racket

(define rv_zbc-rd
  (make-immutable-hash
    '(
      (clmul . 1)
      (clmulr . 1)
      (clmulh . 1)
    )))
(define rv_zbc-rs1
  (make-immutable-hash
    '(
      (clmul . 2)
      (clmulr . 2)
      (clmulh . 2)
    )))
(define rv_zbc-rs2
  (make-immutable-hash
    '(
      (clmul . 3)
      (clmulr . 3)
      (clmulh . 3)
    )))

(define rv_zbc-fields '(rd rs1 rs2))

(define rv_zbc-param-count
  (make-immutable-hash
    '(
      (clmul . 3)
      (clmulr . 3)
      (clmulh . 3)
    )))

(define rv_zbc-operands
  (make-immutable-hash
    '(
      (clmul . (rd rs1 rs2))
      (clmulr . (rd rs1 rs2))
      (clmulh . (rd rs1 rs2))
    )))

(define rv_zbc-asm
  (make-immutable-hash
    '(
      (clmul . "clmul rd, rs1, rs2")
      (clmulr . "clmulr rd, rs1, rs2")
      (clmulh . "clmulh rd, rs1, rs2")
    )))

(define rv_zbc-operand-types
  (make-immutable-hash
    '(
      (clmul . (reg reg reg))
      (clmulr . (reg reg reg))
      (clmulh . (reg reg reg))
    )))

(define rv_zbc-width 32)

;; ====== Helper functions ======

(define (rv_zbc-get-param-count mnemonic)
  (hash-ref rv_zbc-param-count mnemonic #f))

(define (rv_zbc-get-operands mnemonic)
  (hash-ref rv_zbc-operands mnemonic '()))

(define (rv_zbc-get-asm mnemonic)
  (hash-ref rv_zbc-asm mnemonic #f))

(define (rv_zbc-get-operand-types mnemonic)
  (hash-ref rv_zbc-operand-types mnemonic '()))

(define (rv_zbc-get-width) rv_zbc-width)

(define (rv_zbc-exists? mnemonic)
  (hash-has-key? rv_zbc-param-count mnemonic))

(define (rv_zbc-get-field-position mnemonic field)
  (case field
    [(rd) (hash-ref rv_zbc-rd mnemonic #f)]
    [(rs1) (hash-ref rv_zbc-rs1 mnemonic #f)]
    [(rs2) (hash-ref rv_zbc-rs2 mnemonic #f)]
    [else #f]))

(provide
  rv_zbc-rd
  rv_zbc-rs1
  rv_zbc-rs2
  rv_zbc-fields
  rv_zbc-param-count
  rv_zbc-operands
  rv_zbc-asm
  rv_zbc-operand-types
  rv_zbc-width
  rv_zbc-get-param-count
  rv_zbc-get-operands
  rv_zbc-get-asm
  rv_zbc-get-operand-types
  rv_zbc-get-width
  rv_zbc-exists?
  rv_zbc-get-field-position)
