#lang racket

(define rv_q_zfhmin-rd
  (make-immutable-hash
    '(
      (fcvt.q.h . 1)
      (fcvt.h.q . 1)
    )))
(define rv_q_zfhmin-rs1
  (make-immutable-hash
    '(
      (fcvt.q.h . 2)
      (fcvt.h.q . 2)
    )))
(define rv_q_zfhmin-rm
  (make-immutable-hash
    '(
      (fcvt.q.h . 3)
      (fcvt.h.q . 3)
    )))

(define rv_q_zfhmin-fields '(rd rs1 rm))

(define rv_q_zfhmin-param-count
  (make-immutable-hash
    '(
      (fcvt.q.h . 3)
      (fcvt.h.q . 3)
    )))

(define rv_q_zfhmin-operands
  (make-immutable-hash
    '(
      (fcvt.q.h . (rd rs1 rm))
      (fcvt.h.q . (rd rs1 rm))
    )))

(define rv_q_zfhmin-asm
  (make-immutable-hash
    '(
      (fcvt.q.h . "fcvt.q.h rd, rs1, rm")
      (fcvt.h.q . "fcvt.h.q rd, rs1, rm")
    )))

(define rv_q_zfhmin-operand-types
  (make-immutable-hash
    '(
      (fcvt.q.h . (reg reg imm))
      (fcvt.h.q . (reg reg imm))
    )))

(define rv_q_zfhmin-width 32)

;; ====== Helper functions ======

(define (rv_q_zfhmin-get-param-count mnemonic)
  (hash-ref rv_q_zfhmin-param-count mnemonic #f))

(define (rv_q_zfhmin-get-operands mnemonic)
  (hash-ref rv_q_zfhmin-operands mnemonic '()))

(define (rv_q_zfhmin-get-asm mnemonic)
  (hash-ref rv_q_zfhmin-asm mnemonic #f))

(define (rv_q_zfhmin-get-operand-types mnemonic)
  (hash-ref rv_q_zfhmin-operand-types mnemonic '()))

(define (rv_q_zfhmin-get-width) rv_q_zfhmin-width)

(define (rv_q_zfhmin-exists? mnemonic)
  (hash-has-key? rv_q_zfhmin-param-count mnemonic))

(define (rv_q_zfhmin-get-field-position mnemonic field)
  (case field
    [(rd) (hash-ref rv_q_zfhmin-rd mnemonic #f)]
    [(rs1) (hash-ref rv_q_zfhmin-rs1 mnemonic #f)]
    [(rm) (hash-ref rv_q_zfhmin-rm mnemonic #f)]
    [else #f]))

(provide
  rv_q_zfhmin-rd
  rv_q_zfhmin-rs1
  rv_q_zfhmin-rm
  rv_q_zfhmin-fields
  rv_q_zfhmin-param-count
  rv_q_zfhmin-operands
  rv_q_zfhmin-asm
  rv_q_zfhmin-operand-types
  rv_q_zfhmin-width
  rv_q_zfhmin-get-param-count
  rv_q_zfhmin-get-operands
  rv_q_zfhmin-get-asm
  rv_q_zfhmin-get-operand-types
  rv_q_zfhmin-get-width
  rv_q_zfhmin-exists?
  rv_q_zfhmin-get-field-position)
