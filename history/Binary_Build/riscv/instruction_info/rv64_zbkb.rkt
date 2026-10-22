#lang racket

(define rv64_zbkb-rd
  (make-immutable-hash
    '(
      (packw . 1)
    )))
(define rv64_zbkb-rs1
  (make-immutable-hash
    '(
      (packw . 2)
    )))
(define rv64_zbkb-rs2
  (make-immutable-hash
    '(
      (packw . 3)
    )))

(define rv64_zbkb-fields '(rd rs1 rs2))

(define rv64_zbkb-param-count
  (make-immutable-hash
    '(
      (packw . 3)
    )))

(define rv64_zbkb-operands
  (make-immutable-hash
    '(
      (packw . (rd rs1 rs2))
    )))

(define rv64_zbkb-asm
  (make-immutable-hash
    '(
      (packw . "packw rd, rs1, rs2")
    )))

(define rv64_zbkb-operand-types
  (make-immutable-hash
    '(
      (packw . (reg reg reg))
    )))

(define rv64_zbkb-width 32)

;; ====== Helper functions ======

(define (rv64_zbkb-get-param-count mnemonic)
  (hash-ref rv64_zbkb-param-count mnemonic #f))

(define (rv64_zbkb-get-operands mnemonic)
  (hash-ref rv64_zbkb-operands mnemonic '()))

(define (rv64_zbkb-get-asm mnemonic)
  (hash-ref rv64_zbkb-asm mnemonic #f))

(define (rv64_zbkb-get-operand-types mnemonic)
  (hash-ref rv64_zbkb-operand-types mnemonic '()))

(define (rv64_zbkb-get-width) rv64_zbkb-width)

(define (rv64_zbkb-exists? mnemonic)
  (hash-has-key? rv64_zbkb-param-count mnemonic))

(define (rv64_zbkb-get-field-position mnemonic field)
  (case field
    [(rd) (hash-ref rv64_zbkb-rd mnemonic #f)]
    [(rs1) (hash-ref rv64_zbkb-rs1 mnemonic #f)]
    [(rs2) (hash-ref rv64_zbkb-rs2 mnemonic #f)]
    [else #f]))

(provide
  rv64_zbkb-rd
  rv64_zbkb-rs1
  rv64_zbkb-rs2
  rv64_zbkb-fields
  rv64_zbkb-param-count
  rv64_zbkb-operands
  rv64_zbkb-asm
  rv64_zbkb-operand-types
  rv64_zbkb-width
  rv64_zbkb-get-param-count
  rv64_zbkb-get-operands
  rv64_zbkb-get-asm
  rv64_zbkb-get-operand-types
  rv64_zbkb-get-width
  rv64_zbkb-exists?
  rv64_zbkb-get-field-position)
