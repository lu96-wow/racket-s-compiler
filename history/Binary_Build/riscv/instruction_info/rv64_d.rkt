#lang racket

(define rv64_d-rd
  (make-immutable-hash
    '(
      (fcvt.l.d . 1)
      (fcvt.lu.d . 1)
      (fmv.x.d . 1)
      (fcvt.d.l . 1)
      (fcvt.d.lu . 1)
      (fmv.d.x . 1)
    )))
(define rv64_d-rs1
  (make-immutable-hash
    '(
      (fcvt.l.d . 2)
      (fcvt.lu.d . 2)
      (fmv.x.d . 2)
      (fcvt.d.l . 2)
      (fcvt.d.lu . 2)
      (fmv.d.x . 2)
    )))
(define rv64_d-rm
  (make-immutable-hash
    '(
      (fcvt.l.d . 3)
      (fcvt.lu.d . 3)
      (fcvt.d.l . 3)
      (fcvt.d.lu . 3)
    )))

(define rv64_d-fields '(rd rs1 rm))

(define rv64_d-param-count
  (make-immutable-hash
    '(
      (fcvt.l.d . 3)
      (fcvt.lu.d . 3)
      (fmv.x.d . 2)
      (fcvt.d.l . 3)
      (fcvt.d.lu . 3)
      (fmv.d.x . 2)
    )))

(define rv64_d-operands
  (make-immutable-hash
    '(
      (fcvt.l.d . (rd rs1 rm))
      (fcvt.lu.d . (rd rs1 rm))
      (fmv.x.d . (rd rs1))
      (fcvt.d.l . (rd rs1 rm))
      (fcvt.d.lu . (rd rs1 rm))
      (fmv.d.x . (rd rs1))
    )))

(define rv64_d-asm
  (make-immutable-hash
    '(
      (fcvt.l.d . "fcvt.l.d rd, rs1, rm")
      (fcvt.lu.d . "fcvt.lu.d rd, rs1, rm")
      (fmv.x.d . "fmv.x.d rd, rs1")
      (fcvt.d.l . "fcvt.d.l rd, rs1, rm")
      (fcvt.d.lu . "fcvt.d.lu rd, rs1, rm")
      (fmv.d.x . "fmv.d.x rd, rs1")
    )))

(define rv64_d-operand-types
  (make-immutable-hash
    '(
      (fcvt.l.d . (reg reg imm))
      (fcvt.lu.d . (reg reg imm))
      (fmv.x.d . (reg reg))
      (fcvt.d.l . (reg reg imm))
      (fcvt.d.lu . (reg reg imm))
      (fmv.d.x . (reg reg))
    )))

(define rv64_d-width 32)

;; ====== Helper functions ======

(define (rv64_d-get-param-count mnemonic)
  (hash-ref rv64_d-param-count mnemonic #f))

(define (rv64_d-get-operands mnemonic)
  (hash-ref rv64_d-operands mnemonic '()))

(define (rv64_d-get-asm mnemonic)
  (hash-ref rv64_d-asm mnemonic #f))

(define (rv64_d-get-operand-types mnemonic)
  (hash-ref rv64_d-operand-types mnemonic '()))

(define (rv64_d-get-width) rv64_d-width)

(define (rv64_d-exists? mnemonic)
  (hash-has-key? rv64_d-param-count mnemonic))

(define (rv64_d-get-field-position mnemonic field)
  (case field
    [(rd) (hash-ref rv64_d-rd mnemonic #f)]
    [(rs1) (hash-ref rv64_d-rs1 mnemonic #f)]
    [(rm) (hash-ref rv64_d-rm mnemonic #f)]
    [else #f]))

(provide
  rv64_d-rd
  rv64_d-rs1
  rv64_d-rm
  rv64_d-fields
  rv64_d-param-count
  rv64_d-operands
  rv64_d-asm
  rv64_d-operand-types
  rv64_d-width
  rv64_d-get-param-count
  rv64_d-get-operands
  rv64_d-get-asm
  rv64_d-get-operand-types
  rv64_d-get-width
  rv64_d-exists?
  rv64_d-get-field-position)
