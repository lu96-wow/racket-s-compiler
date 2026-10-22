#lang racket

(define rv_zbkx-rd
  (make-immutable-hash
    '(
      (xperm4 . 1)
      (xperm8 . 1)
    )))
(define rv_zbkx-rs1
  (make-immutable-hash
    '(
      (xperm4 . 2)
      (xperm8 . 2)
    )))
(define rv_zbkx-rs2
  (make-immutable-hash
    '(
      (xperm4 . 3)
      (xperm8 . 3)
    )))

(define rv_zbkx-fields '(rd rs1 rs2))

(define rv_zbkx-param-count
  (make-immutable-hash
    '(
      (xperm4 . 3)
      (xperm8 . 3)
    )))

(define rv_zbkx-operands
  (make-immutable-hash
    '(
      (xperm4 . (rd rs1 rs2))
      (xperm8 . (rd rs1 rs2))
    )))

(define rv_zbkx-asm
  (make-immutable-hash
    '(
      (xperm4 . "xperm4 rd, rs1, rs2")
      (xperm8 . "xperm8 rd, rs1, rs2")
    )))

(define rv_zbkx-operand-types
  (make-immutable-hash
    '(
      (xperm4 . (reg reg reg))
      (xperm8 . (reg reg reg))
    )))

(define rv_zbkx-width 32)

;; ====== Helper functions ======

(define (rv_zbkx-get-param-count mnemonic)
  (hash-ref rv_zbkx-param-count mnemonic #f))

(define (rv_zbkx-get-operands mnemonic)
  (hash-ref rv_zbkx-operands mnemonic '()))

(define (rv_zbkx-get-asm mnemonic)
  (hash-ref rv_zbkx-asm mnemonic #f))

(define (rv_zbkx-get-operand-types mnemonic)
  (hash-ref rv_zbkx-operand-types mnemonic '()))

(define (rv_zbkx-get-width) rv_zbkx-width)

(define (rv_zbkx-exists? mnemonic)
  (hash-has-key? rv_zbkx-param-count mnemonic))

(define (rv_zbkx-get-field-position mnemonic field)
  (case field
    [(rd) (hash-ref rv_zbkx-rd mnemonic #f)]
    [(rs1) (hash-ref rv_zbkx-rs1 mnemonic #f)]
    [(rs2) (hash-ref rv_zbkx-rs2 mnemonic #f)]
    [else #f]))

(provide
  rv_zbkx-rd
  rv_zbkx-rs1
  rv_zbkx-rs2
  rv_zbkx-fields
  rv_zbkx-param-count
  rv_zbkx-operands
  rv_zbkx-asm
  rv_zbkx-operand-types
  rv_zbkx-width
  rv_zbkx-get-param-count
  rv_zbkx-get-operands
  rv_zbkx-get-asm
  rv_zbkx-get-operand-types
  rv_zbkx-get-width
  rv_zbkx-exists?
  rv_zbkx-get-field-position)
