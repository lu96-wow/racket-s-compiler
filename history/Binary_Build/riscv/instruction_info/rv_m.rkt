#lang racket

(define rv_m-rd
  (make-immutable-hash
    '(
      (mul . 1)
      (mulh . 1)
      (mulhsu . 1)
      (mulhu . 1)
      (div . 1)
      (divu . 1)
      (rem . 1)
      (remu . 1)
    )))
(define rv_m-rs1
  (make-immutable-hash
    '(
      (mul . 2)
      (mulh . 2)
      (mulhsu . 2)
      (mulhu . 2)
      (div . 2)
      (divu . 2)
      (rem . 2)
      (remu . 2)
    )))
(define rv_m-rs2
  (make-immutable-hash
    '(
      (mul . 3)
      (mulh . 3)
      (mulhsu . 3)
      (mulhu . 3)
      (div . 3)
      (divu . 3)
      (rem . 3)
      (remu . 3)
    )))

(define rv_m-fields '(rd rs1 rs2))

(define rv_m-param-count
  (make-immutable-hash
    '(
      (mul . 3)
      (mulh . 3)
      (mulhsu . 3)
      (mulhu . 3)
      (div . 3)
      (divu . 3)
      (rem . 3)
      (remu . 3)
    )))

(define rv_m-operands
  (make-immutable-hash
    '(
      (mul . (rd rs1 rs2))
      (mulh . (rd rs1 rs2))
      (mulhsu . (rd rs1 rs2))
      (mulhu . (rd rs1 rs2))
      (div . (rd rs1 rs2))
      (divu . (rd rs1 rs2))
      (rem . (rd rs1 rs2))
      (remu . (rd rs1 rs2))
    )))

(define rv_m-asm
  (make-immutable-hash
    '(
      (mul . "mul rd, rs1, rs2")
      (mulh . "mulh rd, rs1, rs2")
      (mulhsu . "mulhsu rd, rs1, rs2")
      (mulhu . "mulhu rd, rs1, rs2")
      (div . "div rd, rs1, rs2")
      (divu . "divu rd, rs1, rs2")
      (rem . "rem rd, rs1, rs2")
      (remu . "remu rd, rs1, rs2")
    )))

(define rv_m-operand-types
  (make-immutable-hash
    '(
      (mul . (reg reg reg))
      (mulh . (reg reg reg))
      (mulhsu . (reg reg reg))
      (mulhu . (reg reg reg))
      (div . (reg reg reg))
      (divu . (reg reg reg))
      (rem . (reg reg reg))
      (remu . (reg reg reg))
    )))

(define rv_m-width 32)

;; ====== Helper functions ======

(define (rv_m-get-param-count mnemonic)
  (hash-ref rv_m-param-count mnemonic #f))

(define (rv_m-get-operands mnemonic)
  (hash-ref rv_m-operands mnemonic '()))

(define (rv_m-get-asm mnemonic)
  (hash-ref rv_m-asm mnemonic #f))

(define (rv_m-get-operand-types mnemonic)
  (hash-ref rv_m-operand-types mnemonic '()))

(define (rv_m-get-width) rv_m-width)

(define (rv_m-exists? mnemonic)
  (hash-has-key? rv_m-param-count mnemonic))

(define (rv_m-get-field-position mnemonic field)
  (case field
    [(rd) (hash-ref rv_m-rd mnemonic #f)]
    [(rs1) (hash-ref rv_m-rs1 mnemonic #f)]
    [(rs2) (hash-ref rv_m-rs2 mnemonic #f)]
    [else #f]))

(provide
  rv_m-rd
  rv_m-rs1
  rv_m-rs2
  rv_m-fields
  rv_m-param-count
  rv_m-operands
  rv_m-asm
  rv_m-operand-types
  rv_m-width
  rv_m-get-param-count
  rv_m-get-operands
  rv_m-get-asm
  rv_m-get-operand-types
  rv_m-get-width
  rv_m-exists?
  rv_m-get-field-position)
