#lang racket

(define rv64_zba-rd
  (make-immutable-hash
    '(
      (add.uw . 1)
      (sh1add.uw . 1)
      (sh2add.uw . 1)
      (sh3add.uw . 1)
      (slli.uw . 1)
    )))
(define rv64_zba-rs1
  (make-immutable-hash
    '(
      (add.uw . 2)
      (sh1add.uw . 2)
      (sh2add.uw . 2)
      (sh3add.uw . 2)
      (slli.uw . 2)
    )))
(define rv64_zba-rs2
  (make-immutable-hash
    '(
      (add.uw . 3)
      (sh1add.uw . 3)
      (sh2add.uw . 3)
      (sh3add.uw . 3)
    )))
(define rv64_zba-shamtd
  (make-immutable-hash
    '(
      (slli.uw . 3)
    )))

(define rv64_zba-fields '(rd rs1 rs2 shamtd))

(define rv64_zba-param-count
  (make-immutable-hash
    '(
      (add.uw . 3)
      (sh1add.uw . 3)
      (sh2add.uw . 3)
      (sh3add.uw . 3)
      (slli.uw . 3)
    )))

(define rv64_zba-operands
  (make-immutable-hash
    '(
      (add.uw . (rd rs1 rs2))
      (sh1add.uw . (rd rs1 rs2))
      (sh2add.uw . (rd rs1 rs2))
      (sh3add.uw . (rd rs1 rs2))
      (slli.uw . (rd rs1 shamtd))
    )))

(define rv64_zba-asm
  (make-immutable-hash
    '(
      (add.uw . "add.uw rd, rs1, rs2")
      (sh1add.uw . "sh1add.uw rd, rs1, rs2")
      (sh2add.uw . "sh2add.uw rd, rs1, rs2")
      (sh3add.uw . "sh3add.uw rd, rs1, rs2")
      (slli.uw . "slli.uw rd, rs1, shamtd")
    )))

(define rv64_zba-operand-types
  (make-immutable-hash
    '(
      (add.uw . (reg reg reg))
      (sh1add.uw . (reg reg reg))
      (sh2add.uw . (reg reg reg))
      (sh3add.uw . (reg reg reg))
      (slli.uw . (reg reg imm))
    )))

(define rv64_zba-width 32)

;; ====== Helper functions ======

(define (rv64_zba-get-param-count mnemonic)
  (hash-ref rv64_zba-param-count mnemonic #f))

(define (rv64_zba-get-operands mnemonic)
  (hash-ref rv64_zba-operands mnemonic '()))

(define (rv64_zba-get-asm mnemonic)
  (hash-ref rv64_zba-asm mnemonic #f))

(define (rv64_zba-get-operand-types mnemonic)
  (hash-ref rv64_zba-operand-types mnemonic '()))

(define (rv64_zba-get-width) rv64_zba-width)

(define (rv64_zba-exists? mnemonic)
  (hash-has-key? rv64_zba-param-count mnemonic))

(define (rv64_zba-get-field-position mnemonic field)
  (case field
    [(rd) (hash-ref rv64_zba-rd mnemonic #f)]
    [(rs1) (hash-ref rv64_zba-rs1 mnemonic #f)]
    [(rs2) (hash-ref rv64_zba-rs2 mnemonic #f)]
    [(shamtd) (hash-ref rv64_zba-shamtd mnemonic #f)]
    [else #f]))

(provide
  rv64_zba-rd
  rv64_zba-rs1
  rv64_zba-rs2
  rv64_zba-shamtd
  rv64_zba-fields
  rv64_zba-param-count
  rv64_zba-operands
  rv64_zba-asm
  rv64_zba-operand-types
  rv64_zba-width
  rv64_zba-get-param-count
  rv64_zba-get-operands
  rv64_zba-get-asm
  rv64_zba-get-operand-types
  rv64_zba-get-width
  rv64_zba-exists?
  rv64_zba-get-field-position)
