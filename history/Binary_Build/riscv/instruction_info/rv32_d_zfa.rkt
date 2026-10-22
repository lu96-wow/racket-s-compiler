#lang racket

(define rv32_d_zfa-rd
  (make-immutable-hash
    '(
      (fmvh.x.d . 1)
      (fmvp.d.x . 1)
    )))
(define rv32_d_zfa-rs1
  (make-immutable-hash
    '(
      (fmvh.x.d . 2)
      (fmvp.d.x . 2)
    )))
(define rv32_d_zfa-rs2
  (make-immutable-hash
    '(
      (fmvp.d.x . 3)
    )))

(define rv32_d_zfa-fields '(rd rs1 rs2))

(define rv32_d_zfa-param-count
  (make-immutable-hash
    '(
      (fmvh.x.d . 2)
      (fmvp.d.x . 3)
    )))

(define rv32_d_zfa-operands
  (make-immutable-hash
    '(
      (fmvh.x.d . (rd rs1))
      (fmvp.d.x . (rd rs1 rs2))
    )))

(define rv32_d_zfa-asm
  (make-immutable-hash
    '(
      (fmvh.x.d . "fmvh.x.d rd, rs1")
      (fmvp.d.x . "fmvp.d.x rd, rs1, rs2")
    )))

(define rv32_d_zfa-operand-types
  (make-immutable-hash
    '(
      (fmvh.x.d . (reg reg))
      (fmvp.d.x . (reg reg reg))
    )))

(define rv32_d_zfa-width 32)

;; ====== Helper functions ======

(define (rv32_d_zfa-get-param-count mnemonic)
  (hash-ref rv32_d_zfa-param-count mnemonic #f))

(define (rv32_d_zfa-get-operands mnemonic)
  (hash-ref rv32_d_zfa-operands mnemonic '()))

(define (rv32_d_zfa-get-asm mnemonic)
  (hash-ref rv32_d_zfa-asm mnemonic #f))

(define (rv32_d_zfa-get-operand-types mnemonic)
  (hash-ref rv32_d_zfa-operand-types mnemonic '()))

(define (rv32_d_zfa-get-width) rv32_d_zfa-width)

(define (rv32_d_zfa-exists? mnemonic)
  (hash-has-key? rv32_d_zfa-param-count mnemonic))

(define (rv32_d_zfa-get-field-position mnemonic field)
  (case field
    [(rd) (hash-ref rv32_d_zfa-rd mnemonic #f)]
    [(rs1) (hash-ref rv32_d_zfa-rs1 mnemonic #f)]
    [(rs2) (hash-ref rv32_d_zfa-rs2 mnemonic #f)]
    [else #f]))

(provide
  rv32_d_zfa-rd
  rv32_d_zfa-rs1
  rv32_d_zfa-rs2
  rv32_d_zfa-fields
  rv32_d_zfa-param-count
  rv32_d_zfa-operands
  rv32_d_zfa-asm
  rv32_d_zfa-operand-types
  rv32_d_zfa-width
  rv32_d_zfa-get-param-count
  rv32_d_zfa-get-operands
  rv32_d_zfa-get-asm
  rv32_d_zfa-get-operand-types
  rv32_d_zfa-get-width
  rv32_d_zfa-exists?
  rv32_d_zfa-get-field-position)
