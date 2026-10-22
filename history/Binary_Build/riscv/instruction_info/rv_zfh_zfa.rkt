#lang racket

(define rv_zfh_zfa-rd
  (make-immutable-hash
    '(
      (fli.h . 1)
      (fminm.h . 1)
      (fmaxm.h . 1)
      (fround.h . 1)
      (froundnx.h . 1)
      (fleq.h . 1)
      (fltq.h . 1)
    )))
(define rv_zfh_zfa-rs1
  (make-immutable-hash
    '(
      (fli.h . 2)
      (fminm.h . 2)
      (fmaxm.h . 2)
      (fround.h . 2)
      (froundnx.h . 2)
      (fleq.h . 2)
      (fltq.h . 2)
    )))
(define rv_zfh_zfa-rs2
  (make-immutable-hash
    '(
      (fminm.h . 3)
      (fmaxm.h . 3)
      (fleq.h . 3)
      (fltq.h . 3)
    )))
(define rv_zfh_zfa-rm
  (make-immutable-hash
    '(
      (fround.h . 3)
      (froundnx.h . 3)
    )))

(define rv_zfh_zfa-fields '(rd rs1 rs2 rm))

(define rv_zfh_zfa-param-count
  (make-immutable-hash
    '(
      (fli.h . 2)
      (fminm.h . 3)
      (fmaxm.h . 3)
      (fround.h . 3)
      (froundnx.h . 3)
      (fleq.h . 3)
      (fltq.h . 3)
    )))

(define rv_zfh_zfa-operands
  (make-immutable-hash
    '(
      (fli.h . (rd rs1))
      (fminm.h . (rd rs1 rs2))
      (fmaxm.h . (rd rs1 rs2))
      (fround.h . (rd rs1 rm))
      (froundnx.h . (rd rs1 rm))
      (fleq.h . (rd rs1 rs2))
      (fltq.h . (rd rs1 rs2))
    )))

(define rv_zfh_zfa-asm
  (make-immutable-hash
    '(
      (fli.h . "fli.h rd, rs1")
      (fminm.h . "fminm.h rd, rs1, rs2")
      (fmaxm.h . "fmaxm.h rd, rs1, rs2")
      (fround.h . "fround.h rd, rs1, rm")
      (froundnx.h . "froundnx.h rd, rs1, rm")
      (fleq.h . "fleq.h rd, rs1, rs2")
      (fltq.h . "fltq.h rd, rs1, rs2")
    )))

(define rv_zfh_zfa-operand-types
  (make-immutable-hash
    '(
      (fli.h . (reg reg))
      (fminm.h . (reg reg reg))
      (fmaxm.h . (reg reg reg))
      (fround.h . (reg reg imm))
      (froundnx.h . (reg reg imm))
      (fleq.h . (reg reg reg))
      (fltq.h . (reg reg reg))
    )))

(define rv_zfh_zfa-width 32)

;; ====== Helper functions ======

(define (rv_zfh_zfa-get-param-count mnemonic)
  (hash-ref rv_zfh_zfa-param-count mnemonic #f))

(define (rv_zfh_zfa-get-operands mnemonic)
  (hash-ref rv_zfh_zfa-operands mnemonic '()))

(define (rv_zfh_zfa-get-asm mnemonic)
  (hash-ref rv_zfh_zfa-asm mnemonic #f))

(define (rv_zfh_zfa-get-operand-types mnemonic)
  (hash-ref rv_zfh_zfa-operand-types mnemonic '()))

(define (rv_zfh_zfa-get-width) rv_zfh_zfa-width)

(define (rv_zfh_zfa-exists? mnemonic)
  (hash-has-key? rv_zfh_zfa-param-count mnemonic))

(define (rv_zfh_zfa-get-field-position mnemonic field)
  (case field
    [(rd) (hash-ref rv_zfh_zfa-rd mnemonic #f)]
    [(rs1) (hash-ref rv_zfh_zfa-rs1 mnemonic #f)]
    [(rs2) (hash-ref rv_zfh_zfa-rs2 mnemonic #f)]
    [(rm) (hash-ref rv_zfh_zfa-rm mnemonic #f)]
    [else #f]))

(provide
  rv_zfh_zfa-rd
  rv_zfh_zfa-rs1
  rv_zfh_zfa-rs2
  rv_zfh_zfa-rm
  rv_zfh_zfa-fields
  rv_zfh_zfa-param-count
  rv_zfh_zfa-operands
  rv_zfh_zfa-asm
  rv_zfh_zfa-operand-types
  rv_zfh_zfa-width
  rv_zfh_zfa-get-param-count
  rv_zfh_zfa-get-operands
  rv_zfh_zfa-get-asm
  rv_zfh_zfa-get-operand-types
  rv_zfh_zfa-get-width
  rv_zfh_zfa-exists?
  rv_zfh_zfa-get-field-position)
