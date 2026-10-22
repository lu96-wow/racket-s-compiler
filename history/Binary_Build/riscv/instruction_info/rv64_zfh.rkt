#lang racket

(define rv64_zfh-rd
  (make-immutable-hash
    '(
      (fcvt.l.h . 1)
      (fcvt.lu.h . 1)
      (fcvt.h.l . 1)
      (fcvt.h.lu . 1)
    )))
(define rv64_zfh-rs1
  (make-immutable-hash
    '(
      (fcvt.l.h . 2)
      (fcvt.lu.h . 2)
      (fcvt.h.l . 2)
      (fcvt.h.lu . 2)
    )))
(define rv64_zfh-rm
  (make-immutable-hash
    '(
      (fcvt.l.h . 3)
      (fcvt.lu.h . 3)
      (fcvt.h.l . 3)
      (fcvt.h.lu . 3)
    )))

(define rv64_zfh-fields '(rd rs1 rm))

(define rv64_zfh-param-count
  (make-immutable-hash
    '(
      (fcvt.l.h . 3)
      (fcvt.lu.h . 3)
      (fcvt.h.l . 3)
      (fcvt.h.lu . 3)
    )))

(define rv64_zfh-operands
  (make-immutable-hash
    '(
      (fcvt.l.h . (rd rs1 rm))
      (fcvt.lu.h . (rd rs1 rm))
      (fcvt.h.l . (rd rs1 rm))
      (fcvt.h.lu . (rd rs1 rm))
    )))

(define rv64_zfh-asm
  (make-immutable-hash
    '(
      (fcvt.l.h . "fcvt.l.h rd, rs1, rm")
      (fcvt.lu.h . "fcvt.lu.h rd, rs1, rm")
      (fcvt.h.l . "fcvt.h.l rd, rs1, rm")
      (fcvt.h.lu . "fcvt.h.lu rd, rs1, rm")
    )))

(define rv64_zfh-operand-types
  (make-immutable-hash
    '(
      (fcvt.l.h . (reg reg imm))
      (fcvt.lu.h . (reg reg imm))
      (fcvt.h.l . (reg reg imm))
      (fcvt.h.lu . (reg reg imm))
    )))

(define rv64_zfh-width 32)

;; ====== Helper functions ======

(define (rv64_zfh-get-param-count mnemonic)
  (hash-ref rv64_zfh-param-count mnemonic #f))

(define (rv64_zfh-get-operands mnemonic)
  (hash-ref rv64_zfh-operands mnemonic '()))

(define (rv64_zfh-get-asm mnemonic)
  (hash-ref rv64_zfh-asm mnemonic #f))

(define (rv64_zfh-get-operand-types mnemonic)
  (hash-ref rv64_zfh-operand-types mnemonic '()))

(define (rv64_zfh-get-width) rv64_zfh-width)

(define (rv64_zfh-exists? mnemonic)
  (hash-has-key? rv64_zfh-param-count mnemonic))

(define (rv64_zfh-get-field-position mnemonic field)
  (case field
    [(rd) (hash-ref rv64_zfh-rd mnemonic #f)]
    [(rs1) (hash-ref rv64_zfh-rs1 mnemonic #f)]
    [(rm) (hash-ref rv64_zfh-rm mnemonic #f)]
    [else #f]))

(provide
  rv64_zfh-rd
  rv64_zfh-rs1
  rv64_zfh-rm
  rv64_zfh-fields
  rv64_zfh-param-count
  rv64_zfh-operands
  rv64_zfh-asm
  rv64_zfh-operand-types
  rv64_zfh-width
  rv64_zfh-get-param-count
  rv64_zfh-get-operands
  rv64_zfh-get-asm
  rv64_zfh-get-operand-types
  rv64_zfh-get-width
  rv64_zfh-exists?
  rv64_zfh-get-field-position)
