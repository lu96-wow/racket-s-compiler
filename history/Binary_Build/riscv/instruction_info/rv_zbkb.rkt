#lang racket

(define rv_zbkb-rd
  (make-immutable-hash
    '(
      (pack . 1)
      (packh . 1)
      (brev8 . 1)
    )))
(define rv_zbkb-rs1
  (make-immutable-hash
    '(
      (pack . 2)
      (packh . 2)
      (brev8 . 2)
    )))
(define rv_zbkb-rs2
  (make-immutable-hash
    '(
      (pack . 3)
      (packh . 3)
    )))

(define rv_zbkb-fields '(rd rs1 rs2))

(define rv_zbkb-param-count
  (make-immutable-hash
    '(
      (pack . 3)
      (packh . 3)
      (brev8 . 2)
    )))

(define rv_zbkb-operands
  (make-immutable-hash
    '(
      (pack . (rd rs1 rs2))
      (packh . (rd rs1 rs2))
      (brev8 . (rd rs1))
    )))

(define rv_zbkb-asm
  (make-immutable-hash
    '(
      (pack . "pack rd, rs1, rs2")
      (packh . "packh rd, rs1, rs2")
      (brev8 . "brev8 rd, rs1")
    )))

(define rv_zbkb-operand-types
  (make-immutable-hash
    '(
      (pack . (reg reg reg))
      (packh . (reg reg reg))
      (brev8 . (reg reg))
    )))

(define rv_zbkb-width 32)

;; ====== Helper functions ======

(define (rv_zbkb-get-param-count mnemonic)
  (hash-ref rv_zbkb-param-count mnemonic #f))

(define (rv_zbkb-get-operands mnemonic)
  (hash-ref rv_zbkb-operands mnemonic '()))

(define (rv_zbkb-get-asm mnemonic)
  (hash-ref rv_zbkb-asm mnemonic #f))

(define (rv_zbkb-get-operand-types mnemonic)
  (hash-ref rv_zbkb-operand-types mnemonic '()))

(define (rv_zbkb-get-width) rv_zbkb-width)

(define (rv_zbkb-exists? mnemonic)
  (hash-has-key? rv_zbkb-param-count mnemonic))

(define (rv_zbkb-get-field-position mnemonic field)
  (case field
    [(rd) (hash-ref rv_zbkb-rd mnemonic #f)]
    [(rs1) (hash-ref rv_zbkb-rs1 mnemonic #f)]
    [(rs2) (hash-ref rv_zbkb-rs2 mnemonic #f)]
    [else #f]))

(provide
  rv_zbkb-rd
  rv_zbkb-rs1
  rv_zbkb-rs2
  rv_zbkb-fields
  rv_zbkb-param-count
  rv_zbkb-operands
  rv_zbkb-asm
  rv_zbkb-operand-types
  rv_zbkb-width
  rv_zbkb-get-param-count
  rv_zbkb-get-operands
  rv_zbkb-get-asm
  rv_zbkb-get-operand-types
  rv_zbkb-get-width
  rv_zbkb-exists?
  rv_zbkb-get-field-position)
