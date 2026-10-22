#lang racket

(define rv_zacas-rd
  (make-immutable-hash
    '(
      (amocas.w . 1)
      (amocas.d . 1)
    )))
(define rv_zacas-rs1
  (make-immutable-hash
    '(
      (amocas.w . 2)
      (amocas.d . 2)
    )))
(define rv_zacas-rs2
  (make-immutable-hash
    '(
      (amocas.w . 3)
      (amocas.d . 3)
    )))
(define rv_zacas-aq
  (make-immutable-hash
    '(
      (amocas.w . 4)
      (amocas.d . 4)
    )))
(define rv_zacas-rl
  (make-immutable-hash
    '(
      (amocas.w . 5)
      (amocas.d . 5)
    )))

(define rv_zacas-fields '(rd rs1 rs2 aq rl))

(define rv_zacas-param-count
  (make-immutable-hash
    '(
      (amocas.w . 5)
      (amocas.d . 5)
    )))

(define rv_zacas-operands
  (make-immutable-hash
    '(
      (amocas.w . (rd rs1 rs2 aq rl))
      (amocas.d . (rd rs1 rs2 aq rl))
    )))

(define rv_zacas-asm
  (make-immutable-hash
    '(
      (amocas.w . "amocas.w rd, rs1, rs2, aq, rl")
      (amocas.d . "amocas.d rd, rs1, rs2, aq, rl")
    )))

(define rv_zacas-operand-types
  (make-immutable-hash
    '(
      (amocas.w . (reg reg reg imm imm))
      (amocas.d . (reg reg reg imm imm))
    )))

(define rv_zacas-width 32)

;; ====== Helper functions ======

(define (rv_zacas-get-param-count mnemonic)
  (hash-ref rv_zacas-param-count mnemonic #f))

(define (rv_zacas-get-operands mnemonic)
  (hash-ref rv_zacas-operands mnemonic '()))

(define (rv_zacas-get-asm mnemonic)
  (hash-ref rv_zacas-asm mnemonic #f))

(define (rv_zacas-get-operand-types mnemonic)
  (hash-ref rv_zacas-operand-types mnemonic '()))

(define (rv_zacas-get-width) rv_zacas-width)

(define (rv_zacas-exists? mnemonic)
  (hash-has-key? rv_zacas-param-count mnemonic))

(define (rv_zacas-get-field-position mnemonic field)
  (case field
    [(rd) (hash-ref rv_zacas-rd mnemonic #f)]
    [(rs1) (hash-ref rv_zacas-rs1 mnemonic #f)]
    [(rs2) (hash-ref rv_zacas-rs2 mnemonic #f)]
    [(aq) (hash-ref rv_zacas-aq mnemonic #f)]
    [(rl) (hash-ref rv_zacas-rl mnemonic #f)]
    [else #f]))

(provide
  rv_zacas-rd
  rv_zacas-rs1
  rv_zacas-rs2
  rv_zacas-aq
  rv_zacas-rl
  rv_zacas-fields
  rv_zacas-param-count
  rv_zacas-operands
  rv_zacas-asm
  rv_zacas-operand-types
  rv_zacas-width
  rv_zacas-get-param-count
  rv_zacas-get-operands
  rv_zacas-get-asm
  rv_zacas-get-operand-types
  rv_zacas-get-width
  rv_zacas-exists?
  rv_zacas-get-field-position)
