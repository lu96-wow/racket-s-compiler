#lang racket

(define rv_zbs-rd
  (make-immutable-hash
    '(
      (bclr . 1)
      (bext . 1)
      (binv . 1)
      (bset . 1)
    )))
(define rv_zbs-rs1
  (make-immutable-hash
    '(
      (bclr . 2)
      (bext . 2)
      (binv . 2)
      (bset . 2)
    )))
(define rv_zbs-rs2
  (make-immutable-hash
    '(
      (bclr . 3)
      (bext . 3)
      (binv . 3)
      (bset . 3)
    )))

(define rv_zbs-fields '(rd rs1 rs2))

(define rv_zbs-param-count
  (make-immutable-hash
    '(
      (bclr . 3)
      (bext . 3)
      (binv . 3)
      (bset . 3)
    )))

(define rv_zbs-operands
  (make-immutable-hash
    '(
      (bclr . (rd rs1 rs2))
      (bext . (rd rs1 rs2))
      (binv . (rd rs1 rs2))
      (bset . (rd rs1 rs2))
    )))

(define rv_zbs-asm
  (make-immutable-hash
    '(
      (bclr . "bclr rd, rs1, rs2")
      (bext . "bext rd, rs1, rs2")
      (binv . "binv rd, rs1, rs2")
      (bset . "bset rd, rs1, rs2")
    )))

(define rv_zbs-operand-types
  (make-immutable-hash
    '(
      (bclr . (reg reg reg))
      (bext . (reg reg reg))
      (binv . (reg reg reg))
      (bset . (reg reg reg))
    )))

(define rv_zbs-width 32)

;; ====== Helper functions ======

(define (rv_zbs-get-param-count mnemonic)
  (hash-ref rv_zbs-param-count mnemonic #f))

(define (rv_zbs-get-operands mnemonic)
  (hash-ref rv_zbs-operands mnemonic '()))

(define (rv_zbs-get-asm mnemonic)
  (hash-ref rv_zbs-asm mnemonic #f))

(define (rv_zbs-get-operand-types mnemonic)
  (hash-ref rv_zbs-operand-types mnemonic '()))

(define (rv_zbs-get-width) rv_zbs-width)

(define (rv_zbs-exists? mnemonic)
  (hash-has-key? rv_zbs-param-count mnemonic))

(define (rv_zbs-get-field-position mnemonic field)
  (case field
    [(rd) (hash-ref rv_zbs-rd mnemonic #f)]
    [(rs1) (hash-ref rv_zbs-rs1 mnemonic #f)]
    [(rs2) (hash-ref rv_zbs-rs2 mnemonic #f)]
    [else #f]))

(provide
  rv_zbs-rd
  rv_zbs-rs1
  rv_zbs-rs2
  rv_zbs-fields
  rv_zbs-param-count
  rv_zbs-operands
  rv_zbs-asm
  rv_zbs-operand-types
  rv_zbs-width
  rv_zbs-get-param-count
  rv_zbs-get-operands
  rv_zbs-get-asm
  rv_zbs-get-operand-types
  rv_zbs-get-width
  rv_zbs-exists?
  rv_zbs-get-field-position)
