#lang racket

(define rv_d_zfa-rd
  (make-immutable-hash
    '(
      (fli.d . 1)
      (fminm.d . 1)
      (fmaxm.d . 1)
      (fround.d . 1)
      (froundnx.d . 1)
      (fcvtmod.w.d . 1)
      (fleq.d . 1)
      (fltq.d . 1)
    )))
(define rv_d_zfa-rs1
  (make-immutable-hash
    '(
      (fli.d . 2)
      (fminm.d . 2)
      (fmaxm.d . 2)
      (fround.d . 2)
      (froundnx.d . 2)
      (fcvtmod.w.d . 2)
      (fleq.d . 2)
      (fltq.d . 2)
    )))
(define rv_d_zfa-rs2
  (make-immutable-hash
    '(
      (fminm.d . 3)
      (fmaxm.d . 3)
      (fleq.d . 3)
      (fltq.d . 3)
    )))
(define rv_d_zfa-rm
  (make-immutable-hash
    '(
      (fround.d . 3)
      (froundnx.d . 3)
    )))

(define rv_d_zfa-fields '(rd rs1 rs2 rm))

(define rv_d_zfa-param-count
  (make-immutable-hash
    '(
      (fli.d . 2)
      (fminm.d . 3)
      (fmaxm.d . 3)
      (fround.d . 3)
      (froundnx.d . 3)
      (fcvtmod.w.d . 2)
      (fleq.d . 3)
      (fltq.d . 3)
    )))

(define rv_d_zfa-operands
  (make-immutable-hash
    '(
      (fli.d . (rd rs1))
      (fminm.d . (rd rs1 rs2))
      (fmaxm.d . (rd rs1 rs2))
      (fround.d . (rd rs1 rm))
      (froundnx.d . (rd rs1 rm))
      (fcvtmod.w.d . (rd rs1))
      (fleq.d . (rd rs1 rs2))
      (fltq.d . (rd rs1 rs2))
    )))

(define rv_d_zfa-asm
  (make-immutable-hash
    '(
      (fli.d . "fli.d rd, rs1")
      (fminm.d . "fminm.d rd, rs1, rs2")
      (fmaxm.d . "fmaxm.d rd, rs1, rs2")
      (fround.d . "fround.d rd, rs1, rm")
      (froundnx.d . "froundnx.d rd, rs1, rm")
      (fcvtmod.w.d . "fcvtmod.w.d rd, rs1")
      (fleq.d . "fleq.d rd, rs1, rs2")
      (fltq.d . "fltq.d rd, rs1, rs2")
    )))

(define rv_d_zfa-operand-types
  (make-immutable-hash
    '(
      (fli.d . (reg reg))
      (fminm.d . (reg reg reg))
      (fmaxm.d . (reg reg reg))
      (fround.d . (reg reg imm))
      (froundnx.d . (reg reg imm))
      (fcvtmod.w.d . (reg reg))
      (fleq.d . (reg reg reg))
      (fltq.d . (reg reg reg))
    )))

(define rv_d_zfa-width 32)

;; ====== Helper functions ======

(define (rv_d_zfa-get-param-count mnemonic)
  (hash-ref rv_d_zfa-param-count mnemonic #f))

(define (rv_d_zfa-get-operands mnemonic)
  (hash-ref rv_d_zfa-operands mnemonic '()))

(define (rv_d_zfa-get-asm mnemonic)
  (hash-ref rv_d_zfa-asm mnemonic #f))

(define (rv_d_zfa-get-operand-types mnemonic)
  (hash-ref rv_d_zfa-operand-types mnemonic '()))

(define (rv_d_zfa-get-width) rv_d_zfa-width)

(define (rv_d_zfa-exists? mnemonic)
  (hash-has-key? rv_d_zfa-param-count mnemonic))

(define (rv_d_zfa-get-field-position mnemonic field)
  (case field
    [(rd) (hash-ref rv_d_zfa-rd mnemonic #f)]
    [(rs1) (hash-ref rv_d_zfa-rs1 mnemonic #f)]
    [(rs2) (hash-ref rv_d_zfa-rs2 mnemonic #f)]
    [(rm) (hash-ref rv_d_zfa-rm mnemonic #f)]
    [else #f]))

(provide
  rv_d_zfa-rd
  rv_d_zfa-rs1
  rv_d_zfa-rs2
  rv_d_zfa-rm
  rv_d_zfa-fields
  rv_d_zfa-param-count
  rv_d_zfa-operands
  rv_d_zfa-asm
  rv_d_zfa-operand-types
  rv_d_zfa-width
  rv_d_zfa-get-param-count
  rv_d_zfa-get-operands
  rv_d_zfa-get-asm
  rv_d_zfa-get-operand-types
  rv_d_zfa-get-width
  rv_d_zfa-exists?
  rv_d_zfa-get-field-position)
