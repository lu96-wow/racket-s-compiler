#lang racket

(define rv64_q-rd
  (make-immutable-hash
    '(
      (fcvt.l.q . 1)
      (fcvt.lu.q . 1)
      (fcvt.q.l . 1)
      (fcvt.q.lu . 1)
    )))
(define rv64_q-rs1
  (make-immutable-hash
    '(
      (fcvt.l.q . 2)
      (fcvt.lu.q . 2)
      (fcvt.q.l . 2)
      (fcvt.q.lu . 2)
    )))
(define rv64_q-rm
  (make-immutable-hash
    '(
      (fcvt.l.q . 3)
      (fcvt.lu.q . 3)
      (fcvt.q.l . 3)
      (fcvt.q.lu . 3)
    )))

(define rv64_q-fields '(rd rs1 rm))

(define rv64_q-param-count
  (make-immutable-hash
    '(
      (fcvt.l.q . 3)
      (fcvt.lu.q . 3)
      (fcvt.q.l . 3)
      (fcvt.q.lu . 3)
    )))

(define rv64_q-operands
  (make-immutable-hash
    '(
      (fcvt.l.q . (rd rs1 rm))
      (fcvt.lu.q . (rd rs1 rm))
      (fcvt.q.l . (rd rs1 rm))
      (fcvt.q.lu . (rd rs1 rm))
    )))

(define rv64_q-asm
  (make-immutable-hash
    '(
      (fcvt.l.q . "fcvt.l.q rd, rs1, rm")
      (fcvt.lu.q . "fcvt.lu.q rd, rs1, rm")
      (fcvt.q.l . "fcvt.q.l rd, rs1, rm")
      (fcvt.q.lu . "fcvt.q.lu rd, rs1, rm")
    )))

(define rv64_q-operand-types
  (make-immutable-hash
    '(
      (fcvt.l.q . (reg reg imm))
      (fcvt.lu.q . (reg reg imm))
      (fcvt.q.l . (reg reg imm))
      (fcvt.q.lu . (reg reg imm))
    )))

(define rv64_q-width 32)

;; ====== Helper functions ======

(define (rv64_q-get-param-count mnemonic)
  (hash-ref rv64_q-param-count mnemonic #f))

(define (rv64_q-get-operands mnemonic)
  (hash-ref rv64_q-operands mnemonic '()))

(define (rv64_q-get-asm mnemonic)
  (hash-ref rv64_q-asm mnemonic #f))

(define (rv64_q-get-operand-types mnemonic)
  (hash-ref rv64_q-operand-types mnemonic '()))

(define (rv64_q-get-width) rv64_q-width)

(define (rv64_q-exists? mnemonic)
  (hash-has-key? rv64_q-param-count mnemonic))

(define (rv64_q-get-field-position mnemonic field)
  (case field
    [(rd) (hash-ref rv64_q-rd mnemonic #f)]
    [(rs1) (hash-ref rv64_q-rs1 mnemonic #f)]
    [(rm) (hash-ref rv64_q-rm mnemonic #f)]
    [else #f]))

(provide
  rv64_q-rd
  rv64_q-rs1
  rv64_q-rm
  rv64_q-fields
  rv64_q-param-count
  rv64_q-operands
  rv64_q-asm
  rv64_q-operand-types
  rv64_q-width
  rv64_q-get-param-count
  rv64_q-get-operands
  rv64_q-get-asm
  rv64_q-get-operand-types
  rv64_q-get-width
  rv64_q-exists?
  rv64_q-get-field-position)
