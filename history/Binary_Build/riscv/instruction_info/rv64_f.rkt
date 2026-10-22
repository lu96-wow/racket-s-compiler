#lang racket

(define rv64_f-rd
  (make-immutable-hash
    '(
      (fcvt.l.s . 1)
      (fcvt.lu.s . 1)
      (fcvt.s.l . 1)
      (fcvt.s.lu . 1)
    )))
(define rv64_f-rs1
  (make-immutable-hash
    '(
      (fcvt.l.s . 2)
      (fcvt.lu.s . 2)
      (fcvt.s.l . 2)
      (fcvt.s.lu . 2)
    )))
(define rv64_f-rm
  (make-immutable-hash
    '(
      (fcvt.l.s . 3)
      (fcvt.lu.s . 3)
      (fcvt.s.l . 3)
      (fcvt.s.lu . 3)
    )))

(define rv64_f-fields '(rd rs1 rm))

(define rv64_f-param-count
  (make-immutable-hash
    '(
      (fcvt.l.s . 3)
      (fcvt.lu.s . 3)
      (fcvt.s.l . 3)
      (fcvt.s.lu . 3)
    )))

(define rv64_f-operands
  (make-immutable-hash
    '(
      (fcvt.l.s . (rd rs1 rm))
      (fcvt.lu.s . (rd rs1 rm))
      (fcvt.s.l . (rd rs1 rm))
      (fcvt.s.lu . (rd rs1 rm))
    )))

(define rv64_f-asm
  (make-immutable-hash
    '(
      (fcvt.l.s . "fcvt.l.s rd, rs1, rm")
      (fcvt.lu.s . "fcvt.lu.s rd, rs1, rm")
      (fcvt.s.l . "fcvt.s.l rd, rs1, rm")
      (fcvt.s.lu . "fcvt.s.lu rd, rs1, rm")
    )))

(define rv64_f-operand-types
  (make-immutable-hash
    '(
      (fcvt.l.s . (reg reg imm))
      (fcvt.lu.s . (reg reg imm))
      (fcvt.s.l . (reg reg imm))
      (fcvt.s.lu . (reg reg imm))
    )))

(define rv64_f-width 32)

;; ====== Helper functions ======

(define (rv64_f-get-param-count mnemonic)
  (hash-ref rv64_f-param-count mnemonic #f))

(define (rv64_f-get-operands mnemonic)
  (hash-ref rv64_f-operands mnemonic '()))

(define (rv64_f-get-asm mnemonic)
  (hash-ref rv64_f-asm mnemonic #f))

(define (rv64_f-get-operand-types mnemonic)
  (hash-ref rv64_f-operand-types mnemonic '()))

(define (rv64_f-get-width) rv64_f-width)

(define (rv64_f-exists? mnemonic)
  (hash-has-key? rv64_f-param-count mnemonic))

(define (rv64_f-get-field-position mnemonic field)
  (case field
    [(rd) (hash-ref rv64_f-rd mnemonic #f)]
    [(rs1) (hash-ref rv64_f-rs1 mnemonic #f)]
    [(rm) (hash-ref rv64_f-rm mnemonic #f)]
    [else #f]))

(provide
  rv64_f-rd
  rv64_f-rs1
  rv64_f-rm
  rv64_f-fields
  rv64_f-param-count
  rv64_f-operands
  rv64_f-asm
  rv64_f-operand-types
  rv64_f-width
  rv64_f-get-param-count
  rv64_f-get-operands
  rv64_f-get-asm
  rv64_f-get-operand-types
  rv64_f-get-width
  rv64_f-exists?
  rv64_f-get-field-position)
