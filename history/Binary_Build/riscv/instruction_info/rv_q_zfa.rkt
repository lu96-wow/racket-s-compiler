#lang racket

(define rv_q_zfa-rd
  (make-immutable-hash
    '(
      (fli.q . 1)
      (fminm.q . 1)
      (fmaxm.q . 1)
      (fround.q . 1)
      (froundnx.q . 1)
      (fleq.q . 1)
      (fltq.q . 1)
    )))
(define rv_q_zfa-rs1
  (make-immutable-hash
    '(
      (fli.q . 2)
      (fminm.q . 2)
      (fmaxm.q . 2)
      (fround.q . 2)
      (froundnx.q . 2)
      (fleq.q . 2)
      (fltq.q . 2)
    )))
(define rv_q_zfa-rs2
  (make-immutable-hash
    '(
      (fminm.q . 3)
      (fmaxm.q . 3)
      (fleq.q . 3)
      (fltq.q . 3)
    )))
(define rv_q_zfa-rm
  (make-immutable-hash
    '(
      (fround.q . 3)
      (froundnx.q . 3)
    )))

(define rv_q_zfa-fields '(rd rs1 rs2 rm))

(define rv_q_zfa-param-count
  (make-immutable-hash
    '(
      (fli.q . 2)
      (fminm.q . 3)
      (fmaxm.q . 3)
      (fround.q . 3)
      (froundnx.q . 3)
      (fleq.q . 3)
      (fltq.q . 3)
    )))

(define rv_q_zfa-operands
  (make-immutable-hash
    '(
      (fli.q . (rd rs1))
      (fminm.q . (rd rs1 rs2))
      (fmaxm.q . (rd rs1 rs2))
      (fround.q . (rd rs1 rm))
      (froundnx.q . (rd rs1 rm))
      (fleq.q . (rd rs1 rs2))
      (fltq.q . (rd rs1 rs2))
    )))

(define rv_q_zfa-asm
  (make-immutable-hash
    '(
      (fli.q . "fli.q rd, rs1")
      (fminm.q . "fminm.q rd, rs1, rs2")
      (fmaxm.q . "fmaxm.q rd, rs1, rs2")
      (fround.q . "fround.q rd, rs1, rm")
      (froundnx.q . "froundnx.q rd, rs1, rm")
      (fleq.q . "fleq.q rd, rs1, rs2")
      (fltq.q . "fltq.q rd, rs1, rs2")
    )))

(define rv_q_zfa-operand-types
  (make-immutable-hash
    '(
      (fli.q . (reg reg))
      (fminm.q . (reg reg reg))
      (fmaxm.q . (reg reg reg))
      (fround.q . (reg reg imm))
      (froundnx.q . (reg reg imm))
      (fleq.q . (reg reg reg))
      (fltq.q . (reg reg reg))
    )))

(define rv_q_zfa-width 32)

;; ====== Helper functions ======

(define (rv_q_zfa-get-param-count mnemonic)
  (hash-ref rv_q_zfa-param-count mnemonic #f))

(define (rv_q_zfa-get-operands mnemonic)
  (hash-ref rv_q_zfa-operands mnemonic '()))

(define (rv_q_zfa-get-asm mnemonic)
  (hash-ref rv_q_zfa-asm mnemonic #f))

(define (rv_q_zfa-get-operand-types mnemonic)
  (hash-ref rv_q_zfa-operand-types mnemonic '()))

(define (rv_q_zfa-get-width) rv_q_zfa-width)

(define (rv_q_zfa-exists? mnemonic)
  (hash-has-key? rv_q_zfa-param-count mnemonic))

(define (rv_q_zfa-get-field-position mnemonic field)
  (case field
    [(rd) (hash-ref rv_q_zfa-rd mnemonic #f)]
    [(rs1) (hash-ref rv_q_zfa-rs1 mnemonic #f)]
    [(rs2) (hash-ref rv_q_zfa-rs2 mnemonic #f)]
    [(rm) (hash-ref rv_q_zfa-rm mnemonic #f)]
    [else #f]))

(provide
  rv_q_zfa-rd
  rv_q_zfa-rs1
  rv_q_zfa-rs2
  rv_q_zfa-rm
  rv_q_zfa-fields
  rv_q_zfa-param-count
  rv_q_zfa-operands
  rv_q_zfa-asm
  rv_q_zfa-operand-types
  rv_q_zfa-width
  rv_q_zfa-get-param-count
  rv_q_zfa-get-operands
  rv_q_zfa-get-asm
  rv_q_zfa-get-operand-types
  rv_q_zfa-get-width
  rv_q_zfa-exists?
  rv_q_zfa-get-field-position)
