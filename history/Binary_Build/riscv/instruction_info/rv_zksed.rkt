#lang racket

(define rv_zksed-rd
  (make-immutable-hash
    '(
      (sm4ed . 1)
      (sm4ks . 1)
    )))
(define rv_zksed-rs1
  (make-immutable-hash
    '(
      (sm4ed . 2)
      (sm4ks . 2)
    )))
(define rv_zksed-rs2
  (make-immutable-hash
    '(
      (sm4ed . 3)
      (sm4ks . 3)
    )))
(define rv_zksed-bs
  (make-immutable-hash
    '(
      (sm4ed . 4)
      (sm4ks . 4)
    )))

(define rv_zksed-fields '(rd rs1 rs2 bs))

(define rv_zksed-param-count
  (make-immutable-hash
    '(
      (sm4ed . 4)
      (sm4ks . 4)
    )))

(define rv_zksed-operands
  (make-immutable-hash
    '(
      (sm4ed . (rd rs1 rs2 bs))
      (sm4ks . (rd rs1 rs2 bs))
    )))

(define rv_zksed-asm
  (make-immutable-hash
    '(
      (sm4ed . "sm4ed rd, rs1, rs2, bs")
      (sm4ks . "sm4ks rd, rs1, rs2, bs")
    )))

(define rv_zksed-operand-types
  (make-immutable-hash
    '(
      (sm4ed . (reg reg reg imm))
      (sm4ks . (reg reg reg imm))
    )))

(define rv_zksed-width 32)

;; ====== Helper functions ======

(define (rv_zksed-get-param-count mnemonic)
  (hash-ref rv_zksed-param-count mnemonic #f))

(define (rv_zksed-get-operands mnemonic)
  (hash-ref rv_zksed-operands mnemonic '()))

(define (rv_zksed-get-asm mnemonic)
  (hash-ref rv_zksed-asm mnemonic #f))

(define (rv_zksed-get-operand-types mnemonic)
  (hash-ref rv_zksed-operand-types mnemonic '()))

(define (rv_zksed-get-width) rv_zksed-width)

(define (rv_zksed-exists? mnemonic)
  (hash-has-key? rv_zksed-param-count mnemonic))

(define (rv_zksed-get-field-position mnemonic field)
  (case field
    [(rd) (hash-ref rv_zksed-rd mnemonic #f)]
    [(rs1) (hash-ref rv_zksed-rs1 mnemonic #f)]
    [(rs2) (hash-ref rv_zksed-rs2 mnemonic #f)]
    [(bs) (hash-ref rv_zksed-bs mnemonic #f)]
    [else #f]))

(provide
  rv_zksed-rd
  rv_zksed-rs1
  rv_zksed-rs2
  rv_zksed-bs
  rv_zksed-fields
  rv_zksed-param-count
  rv_zksed-operands
  rv_zksed-asm
  rv_zksed-operand-types
  rv_zksed-width
  rv_zksed-get-param-count
  rv_zksed-get-operands
  rv_zksed-get-asm
  rv_zksed-get-operand-types
  rv_zksed-get-width
  rv_zksed-exists?
  rv_zksed-get-field-position)
