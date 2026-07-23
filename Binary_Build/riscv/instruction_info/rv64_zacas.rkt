#lang racket

(define rv64_zacas-rd
  (make-immutable-hash
    '(
      (amocas.q . 1)
    )))
(define rv64_zacas-rs1
  (make-immutable-hash
    '(
      (amocas.q . 2)
    )))
(define rv64_zacas-rs2
  (make-immutable-hash
    '(
      (amocas.q . 3)
    )))
(define rv64_zacas-aq
  (make-immutable-hash
    '(
      (amocas.q . 4)
    )))
(define rv64_zacas-rl
  (make-immutable-hash
    '(
      (amocas.q . 5)
    )))

(define rv64_zacas-fields '(rd rs1 rs2 aq rl))

(define rv64_zacas-param-count
  (make-immutable-hash
    '(
      (amocas.q . 5)
    )))

(define rv64_zacas-operands
  (make-immutable-hash
    '(
      (amocas.q . (rd rs1 rs2 aq rl))
    )))

(define rv64_zacas-asm
  (make-immutable-hash
    '(
      (amocas.q . "amocas.q rd, rs1, rs2, aq, rl")
    )))

(define rv64_zacas-operand-types
  (make-immutable-hash
    '(
      (amocas.q . (reg reg reg imm imm))
    )))

(define rv64_zacas-width 32)

;; ====== Helper functions ======

(define (rv64_zacas-get-param-count mnemonic)
  (hash-ref rv64_zacas-param-count mnemonic #f))

(define (rv64_zacas-get-operands mnemonic)
  (hash-ref rv64_zacas-operands mnemonic '()))

(define (rv64_zacas-get-asm mnemonic)
  (hash-ref rv64_zacas-asm mnemonic #f))

(define (rv64_zacas-get-operand-types mnemonic)
  (hash-ref rv64_zacas-operand-types mnemonic '()))

(define (rv64_zacas-get-width) rv64_zacas-width)

(define (rv64_zacas-exists? mnemonic)
  (hash-has-key? rv64_zacas-param-count mnemonic))

(define (rv64_zacas-get-field-position mnemonic field)
  (case field
    [(rd) (hash-ref rv64_zacas-rd mnemonic #f)]
    [(rs1) (hash-ref rv64_zacas-rs1 mnemonic #f)]
    [(rs2) (hash-ref rv64_zacas-rs2 mnemonic #f)]
    [(aq) (hash-ref rv64_zacas-aq mnemonic #f)]
    [(rl) (hash-ref rv64_zacas-rl mnemonic #f)]
    [else #f]))

(provide
  rv64_zacas-rd
  rv64_zacas-rs1
  rv64_zacas-rs2
  rv64_zacas-aq
  rv64_zacas-rl
  rv64_zacas-fields
  rv64_zacas-param-count
  rv64_zacas-operands
  rv64_zacas-asm
  rv64_zacas-operand-types
  rv64_zacas-width
  rv64_zacas-get-param-count
  rv64_zacas-get-operands
  rv64_zacas-get-asm
  rv64_zacas-get-operand-types
  rv64_zacas-get-width
  rv64_zacas-exists?
  rv64_zacas-get-field-position)
