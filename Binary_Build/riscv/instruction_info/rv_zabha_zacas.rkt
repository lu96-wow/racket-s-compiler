#lang racket

(define rv_zabha_zacas-rd
  (make-immutable-hash
    '(
      (amocas.b . 1)
      (amocas.h . 1)
    )))
(define rv_zabha_zacas-rs1
  (make-immutable-hash
    '(
      (amocas.b . 2)
      (amocas.h . 2)
    )))
(define rv_zabha_zacas-rs2
  (make-immutable-hash
    '(
      (amocas.b . 3)
      (amocas.h . 3)
    )))
(define rv_zabha_zacas-aq
  (make-immutable-hash
    '(
      (amocas.b . 4)
      (amocas.h . 4)
    )))
(define rv_zabha_zacas-rl
  (make-immutable-hash
    '(
      (amocas.b . 5)
      (amocas.h . 5)
    )))

(define rv_zabha_zacas-fields '(rd rs1 rs2 aq rl))

(define rv_zabha_zacas-param-count
  (make-immutable-hash
    '(
      (amocas.b . 5)
      (amocas.h . 5)
    )))

(define rv_zabha_zacas-operands
  (make-immutable-hash
    '(
      (amocas.b . (rd rs1 rs2 aq rl))
      (amocas.h . (rd rs1 rs2 aq rl))
    )))

(define rv_zabha_zacas-asm
  (make-immutable-hash
    '(
      (amocas.b . "amocas.b rd, rs1, rs2, aq, rl")
      (amocas.h . "amocas.h rd, rs1, rs2, aq, rl")
    )))

(define rv_zabha_zacas-operand-types
  (make-immutable-hash
    '(
      (amocas.b . (reg reg reg imm imm))
      (amocas.h . (reg reg reg imm imm))
    )))

(define rv_zabha_zacas-width 32)

;; ====== Helper functions ======

(define (rv_zabha_zacas-get-param-count mnemonic)
  (hash-ref rv_zabha_zacas-param-count mnemonic #f))

(define (rv_zabha_zacas-get-operands mnemonic)
  (hash-ref rv_zabha_zacas-operands mnemonic '()))

(define (rv_zabha_zacas-get-asm mnemonic)
  (hash-ref rv_zabha_zacas-asm mnemonic #f))

(define (rv_zabha_zacas-get-operand-types mnemonic)
  (hash-ref rv_zabha_zacas-operand-types mnemonic '()))

(define (rv_zabha_zacas-get-width) rv_zabha_zacas-width)

(define (rv_zabha_zacas-exists? mnemonic)
  (hash-has-key? rv_zabha_zacas-param-count mnemonic))

(define (rv_zabha_zacas-get-field-position mnemonic field)
  (case field
    [(rd) (hash-ref rv_zabha_zacas-rd mnemonic #f)]
    [(rs1) (hash-ref rv_zabha_zacas-rs1 mnemonic #f)]
    [(rs2) (hash-ref rv_zabha_zacas-rs2 mnemonic #f)]
    [(aq) (hash-ref rv_zabha_zacas-aq mnemonic #f)]
    [(rl) (hash-ref rv_zabha_zacas-rl mnemonic #f)]
    [else #f]))

(provide
  rv_zabha_zacas-rd
  rv_zabha_zacas-rs1
  rv_zabha_zacas-rs2
  rv_zabha_zacas-aq
  rv_zabha_zacas-rl
  rv_zabha_zacas-fields
  rv_zabha_zacas-param-count
  rv_zabha_zacas-operands
  rv_zabha_zacas-asm
  rv_zabha_zacas-operand-types
  rv_zabha_zacas-width
  rv_zabha_zacas-get-param-count
  rv_zabha_zacas-get-operands
  rv_zabha_zacas-get-asm
  rv_zabha_zacas-get-operand-types
  rv_zabha_zacas-get-width
  rv_zabha_zacas-exists?
  rv_zabha_zacas-get-field-position)
