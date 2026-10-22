#lang racket

(define rv_zfbfmin-rd
  (make-immutable-hash
    '(
      (fcvt.bf16.s . 1)
      (fcvt.s.bf16 . 1)
    )))
(define rv_zfbfmin-rs1
  (make-immutable-hash
    '(
      (fcvt.bf16.s . 2)
      (fcvt.s.bf16 . 2)
    )))
(define rv_zfbfmin-rm
  (make-immutable-hash
    '(
      (fcvt.bf16.s . 3)
      (fcvt.s.bf16 . 3)
    )))

(define rv_zfbfmin-fields '(rd rs1 rm))

(define rv_zfbfmin-param-count
  (make-immutable-hash
    '(
      (fcvt.bf16.s . 3)
      (fcvt.s.bf16 . 3)
    )))

(define rv_zfbfmin-operands
  (make-immutable-hash
    '(
      (fcvt.bf16.s . (rd rs1 rm))
      (fcvt.s.bf16 . (rd rs1 rm))
    )))

(define rv_zfbfmin-asm
  (make-immutable-hash
    '(
      (fcvt.bf16.s . "fcvt.bf16.s rd, rs1, rm")
      (fcvt.s.bf16 . "fcvt.s.bf16 rd, rs1, rm")
    )))

(define rv_zfbfmin-operand-types
  (make-immutable-hash
    '(
      (fcvt.bf16.s . (reg reg imm))
      (fcvt.s.bf16 . (reg reg imm))
    )))

(define rv_zfbfmin-width 32)

;; ====== Helper functions ======

(define (rv_zfbfmin-get-param-count mnemonic)
  (hash-ref rv_zfbfmin-param-count mnemonic #f))

(define (rv_zfbfmin-get-operands mnemonic)
  (hash-ref rv_zfbfmin-operands mnemonic '()))

(define (rv_zfbfmin-get-asm mnemonic)
  (hash-ref rv_zfbfmin-asm mnemonic #f))

(define (rv_zfbfmin-get-operand-types mnemonic)
  (hash-ref rv_zfbfmin-operand-types mnemonic '()))

(define (rv_zfbfmin-get-width) rv_zfbfmin-width)

(define (rv_zfbfmin-exists? mnemonic)
  (hash-has-key? rv_zfbfmin-param-count mnemonic))

(define (rv_zfbfmin-get-field-position mnemonic field)
  (case field
    [(rd) (hash-ref rv_zfbfmin-rd mnemonic #f)]
    [(rs1) (hash-ref rv_zfbfmin-rs1 mnemonic #f)]
    [(rm) (hash-ref rv_zfbfmin-rm mnemonic #f)]
    [else #f]))

(provide
  rv_zfbfmin-rd
  rv_zfbfmin-rs1
  rv_zfbfmin-rm
  rv_zfbfmin-fields
  rv_zfbfmin-param-count
  rv_zfbfmin-operands
  rv_zfbfmin-asm
  rv_zfbfmin-operand-types
  rv_zfbfmin-width
  rv_zfbfmin-get-param-count
  rv_zfbfmin-get-operands
  rv_zfbfmin-get-asm
  rv_zfbfmin-get-operand-types
  rv_zfbfmin-get-width
  rv_zfbfmin-exists?
  rv_zfbfmin-get-field-position)
