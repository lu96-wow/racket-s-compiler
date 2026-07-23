#lang racket

(define rv_f_zfa-rd
  (make-immutable-hash
    '(
      (fli.s . 1)
      (fminm.s . 1)
      (fmaxm.s . 1)
      (fround.s . 1)
      (froundnx.s . 1)
      (fleq.s . 1)
      (fltq.s . 1)
    )))
(define rv_f_zfa-rs1
  (make-immutable-hash
    '(
      (fli.s . 2)
      (fminm.s . 2)
      (fmaxm.s . 2)
      (fround.s . 2)
      (froundnx.s . 2)
      (fleq.s . 2)
      (fltq.s . 2)
    )))
(define rv_f_zfa-rs2
  (make-immutable-hash
    '(
      (fminm.s . 3)
      (fmaxm.s . 3)
      (fleq.s . 3)
      (fltq.s . 3)
    )))
(define rv_f_zfa-rm
  (make-immutable-hash
    '(
      (fround.s . 3)
      (froundnx.s . 3)
    )))

(define rv_f_zfa-fields '(rd rs1 rs2 rm))

(define rv_f_zfa-param-count
  (make-immutable-hash
    '(
      (fli.s . 2)
      (fminm.s . 3)
      (fmaxm.s . 3)
      (fround.s . 3)
      (froundnx.s . 3)
      (fleq.s . 3)
      (fltq.s . 3)
    )))

(define rv_f_zfa-operands
  (make-immutable-hash
    '(
      (fli.s . (rd rs1))
      (fminm.s . (rd rs1 rs2))
      (fmaxm.s . (rd rs1 rs2))
      (fround.s . (rd rs1 rm))
      (froundnx.s . (rd rs1 rm))
      (fleq.s . (rd rs1 rs2))
      (fltq.s . (rd rs1 rs2))
    )))

(define rv_f_zfa-asm
  (make-immutable-hash
    '(
      (fli.s . "fli.s rd, rs1")
      (fminm.s . "fminm.s rd, rs1, rs2")
      (fmaxm.s . "fmaxm.s rd, rs1, rs2")
      (fround.s . "fround.s rd, rs1, rm")
      (froundnx.s . "froundnx.s rd, rs1, rm")
      (fleq.s . "fleq.s rd, rs1, rs2")
      (fltq.s . "fltq.s rd, rs1, rs2")
    )))

(define rv_f_zfa-operand-types
  (make-immutable-hash
    '(
      (fli.s . (reg reg))
      (fminm.s . (reg reg reg))
      (fmaxm.s . (reg reg reg))
      (fround.s . (reg reg imm))
      (froundnx.s . (reg reg imm))
      (fleq.s . (reg reg reg))
      (fltq.s . (reg reg reg))
    )))

(define rv_f_zfa-width 32)

;; ====== Helper functions ======

(define (rv_f_zfa-get-param-count mnemonic)
  (hash-ref rv_f_zfa-param-count mnemonic #f))

(define (rv_f_zfa-get-operands mnemonic)
  (hash-ref rv_f_zfa-operands mnemonic '()))

(define (rv_f_zfa-get-asm mnemonic)
  (hash-ref rv_f_zfa-asm mnemonic #f))

(define (rv_f_zfa-get-operand-types mnemonic)
  (hash-ref rv_f_zfa-operand-types mnemonic '()))

(define (rv_f_zfa-get-width) rv_f_zfa-width)

(define (rv_f_zfa-exists? mnemonic)
  (hash-has-key? rv_f_zfa-param-count mnemonic))

(define (rv_f_zfa-get-field-position mnemonic field)
  (case field
    [(rd) (hash-ref rv_f_zfa-rd mnemonic #f)]
    [(rs1) (hash-ref rv_f_zfa-rs1 mnemonic #f)]
    [(rs2) (hash-ref rv_f_zfa-rs2 mnemonic #f)]
    [(rm) (hash-ref rv_f_zfa-rm mnemonic #f)]
    [else #f]))

(provide
  rv_f_zfa-rd
  rv_f_zfa-rs1
  rv_f_zfa-rs2
  rv_f_zfa-rm
  rv_f_zfa-fields
  rv_f_zfa-param-count
  rv_f_zfa-operands
  rv_f_zfa-asm
  rv_f_zfa-operand-types
  rv_f_zfa-width
  rv_f_zfa-get-param-count
  rv_f_zfa-get-operands
  rv_f_zfa-get-asm
  rv_f_zfa-get-operand-types
  rv_f_zfa-get-width
  rv_f_zfa-exists?
  rv_f_zfa-get-field-position)
