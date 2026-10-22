#lang racket

(define rv32_zbkb-rd
  (make-immutable-hash
    '(
      (zip . 1)
      (unzip . 1)
      (rev8.rv32 . 1)
    )))
(define rv32_zbkb-rs1
  (make-immutable-hash
    '(
      (zip . 2)
      (unzip . 2)
      (rev8.rv32 . 2)
    )))

(define rv32_zbkb-fields '(rd rs1))

(define rv32_zbkb-param-count
  (make-immutable-hash
    '(
      (zip . 2)
      (unzip . 2)
      (rev8.rv32 . 2)
    )))

(define rv32_zbkb-operands
  (make-immutable-hash
    '(
      (zip . (rd rs1))
      (unzip . (rd rs1))
      (rev8.rv32 . (rd rs1))
    )))

(define rv32_zbkb-asm
  (make-immutable-hash
    '(
      (zip . "zip rd, rs1")
      (unzip . "unzip rd, rs1")
      (rev8.rv32 . "rev8.rv32 rd, rs1")
    )))

(define rv32_zbkb-operand-types
  (make-immutable-hash
    '(
      (zip . (reg reg))
      (unzip . (reg reg))
      (rev8.rv32 . (reg reg))
    )))

(define rv32_zbkb-width 32)

;; ====== Helper functions ======

(define (rv32_zbkb-get-param-count mnemonic)
  (hash-ref rv32_zbkb-param-count mnemonic #f))

(define (rv32_zbkb-get-operands mnemonic)
  (hash-ref rv32_zbkb-operands mnemonic '()))

(define (rv32_zbkb-get-asm mnemonic)
  (hash-ref rv32_zbkb-asm mnemonic #f))

(define (rv32_zbkb-get-operand-types mnemonic)
  (hash-ref rv32_zbkb-operand-types mnemonic '()))

(define (rv32_zbkb-get-width) rv32_zbkb-width)

(define (rv32_zbkb-exists? mnemonic)
  (hash-has-key? rv32_zbkb-param-count mnemonic))

(define (rv32_zbkb-get-field-position mnemonic field)
  (case field
    [(rd) (hash-ref rv32_zbkb-rd mnemonic #f)]
    [(rs1) (hash-ref rv32_zbkb-rs1 mnemonic #f)]
    [else #f]))

(provide
  rv32_zbkb-rd
  rv32_zbkb-rs1
  rv32_zbkb-fields
  rv32_zbkb-param-count
  rv32_zbkb-operands
  rv32_zbkb-asm
  rv32_zbkb-operand-types
  rv32_zbkb-width
  rv32_zbkb-get-param-count
  rv32_zbkb-get-operands
  rv32_zbkb-get-asm
  rv32_zbkb-get-operand-types
  rv32_zbkb-get-width
  rv32_zbkb-exists?
  rv32_zbkb-get-field-position)
