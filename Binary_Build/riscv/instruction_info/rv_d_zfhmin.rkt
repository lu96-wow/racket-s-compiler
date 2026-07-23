#lang racket

(define rv_d_zfhmin-rd
  (make-immutable-hash
    '(
      (fcvt.d.h . 1)
      (fcvt.h.d . 1)
    )))
(define rv_d_zfhmin-rs1
  (make-immutable-hash
    '(
      (fcvt.d.h . 2)
      (fcvt.h.d . 2)
    )))
(define rv_d_zfhmin-rm
  (make-immutable-hash
    '(
      (fcvt.d.h . 3)
      (fcvt.h.d . 3)
    )))

(define rv_d_zfhmin-fields '(rd rs1 rm))

(define rv_d_zfhmin-param-count
  (make-immutable-hash
    '(
      (fcvt.d.h . 3)
      (fcvt.h.d . 3)
    )))

(define rv_d_zfhmin-operands
  (make-immutable-hash
    '(
      (fcvt.d.h . (rd rs1 rm))
      (fcvt.h.d . (rd rs1 rm))
    )))

(define rv_d_zfhmin-asm
  (make-immutable-hash
    '(
      (fcvt.d.h . "fcvt.d.h rd, rs1, rm")
      (fcvt.h.d . "fcvt.h.d rd, rs1, rm")
    )))

(define rv_d_zfhmin-operand-types
  (make-immutable-hash
    '(
      (fcvt.d.h . (reg reg imm))
      (fcvt.h.d . (reg reg imm))
    )))

(define rv_d_zfhmin-width 32)

;; ====== Helper functions ======

(define (rv_d_zfhmin-get-param-count mnemonic)
  (hash-ref rv_d_zfhmin-param-count mnemonic #f))

(define (rv_d_zfhmin-get-operands mnemonic)
  (hash-ref rv_d_zfhmin-operands mnemonic '()))

(define (rv_d_zfhmin-get-asm mnemonic)
  (hash-ref rv_d_zfhmin-asm mnemonic #f))

(define (rv_d_zfhmin-get-operand-types mnemonic)
  (hash-ref rv_d_zfhmin-operand-types mnemonic '()))

(define (rv_d_zfhmin-get-width) rv_d_zfhmin-width)

(define (rv_d_zfhmin-exists? mnemonic)
  (hash-has-key? rv_d_zfhmin-param-count mnemonic))

(define (rv_d_zfhmin-get-field-position mnemonic field)
  (case field
    [(rd) (hash-ref rv_d_zfhmin-rd mnemonic #f)]
    [(rs1) (hash-ref rv_d_zfhmin-rs1 mnemonic #f)]
    [(rm) (hash-ref rv_d_zfhmin-rm mnemonic #f)]
    [else #f]))

(provide
  rv_d_zfhmin-rd
  rv_d_zfhmin-rs1
  rv_d_zfhmin-rm
  rv_d_zfhmin-fields
  rv_d_zfhmin-param-count
  rv_d_zfhmin-operands
  rv_d_zfhmin-asm
  rv_d_zfhmin-operand-types
  rv_d_zfhmin-width
  rv_d_zfhmin-get-param-count
  rv_d_zfhmin-get-operands
  rv_d_zfhmin-get-asm
  rv_d_zfhmin-get-operand-types
  rv_d_zfhmin-get-width
  rv_d_zfhmin-exists?
  rv_d_zfhmin-get-field-position)
