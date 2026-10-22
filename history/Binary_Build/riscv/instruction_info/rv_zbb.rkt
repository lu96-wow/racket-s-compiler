#lang racket

(define rv_zbb-rd
  (make-immutable-hash
    '(
      (andn . 1)
      (orn . 1)
      (xnor . 1)
      (clz . 1)
      (ctz . 1)
      (cpop . 1)
      (max . 1)
      (maxu . 1)
      (min . 1)
      (minu . 1)
      (sext.b . 1)
      (sext.h . 1)
      (rol . 1)
      (ror . 1)
      (orc.b . 1)
    )))
(define rv_zbb-rs1
  (make-immutable-hash
    '(
      (andn . 2)
      (orn . 2)
      (xnor . 2)
      (clz . 2)
      (ctz . 2)
      (cpop . 2)
      (max . 2)
      (maxu . 2)
      (min . 2)
      (minu . 2)
      (sext.b . 2)
      (sext.h . 2)
      (rol . 2)
      (ror . 2)
      (orc.b . 2)
    )))
(define rv_zbb-rs2
  (make-immutable-hash
    '(
      (andn . 3)
      (orn . 3)
      (xnor . 3)
      (max . 3)
      (maxu . 3)
      (min . 3)
      (minu . 3)
      (rol . 3)
      (ror . 3)
    )))

(define rv_zbb-fields '(rd rs1 rs2))

(define rv_zbb-param-count
  (make-immutable-hash
    '(
      (andn . 3)
      (orn . 3)
      (xnor . 3)
      (clz . 2)
      (ctz . 2)
      (cpop . 2)
      (max . 3)
      (maxu . 3)
      (min . 3)
      (minu . 3)
      (sext.b . 2)
      (sext.h . 2)
      (rol . 3)
      (ror . 3)
      (orc.b . 2)
    )))

(define rv_zbb-operands
  (make-immutable-hash
    '(
      (andn . (rd rs1 rs2))
      (orn . (rd rs1 rs2))
      (xnor . (rd rs1 rs2))
      (clz . (rd rs1))
      (ctz . (rd rs1))
      (cpop . (rd rs1))
      (max . (rd rs1 rs2))
      (maxu . (rd rs1 rs2))
      (min . (rd rs1 rs2))
      (minu . (rd rs1 rs2))
      (sext.b . (rd rs1))
      (sext.h . (rd rs1))
      (rol . (rd rs1 rs2))
      (ror . (rd rs1 rs2))
      (orc.b . (rd rs1))
    )))

(define rv_zbb-asm
  (make-immutable-hash
    '(
      (andn . "andn rd, rs1, rs2")
      (orn . "orn rd, rs1, rs2")
      (xnor . "xnor rd, rs1, rs2")
      (clz . "clz rd, rs1")
      (ctz . "ctz rd, rs1")
      (cpop . "cpop rd, rs1")
      (max . "max rd, rs1, rs2")
      (maxu . "maxu rd, rs1, rs2")
      (min . "min rd, rs1, rs2")
      (minu . "minu rd, rs1, rs2")
      (sext.b . "sext.b rd, rs1")
      (sext.h . "sext.h rd, rs1")
      (rol . "rol rd, rs1, rs2")
      (ror . "ror rd, rs1, rs2")
      (orc.b . "orc.b rd, rs1")
    )))

(define rv_zbb-operand-types
  (make-immutable-hash
    '(
      (andn . (reg reg reg))
      (orn . (reg reg reg))
      (xnor . (reg reg reg))
      (clz . (reg reg))
      (ctz . (reg reg))
      (cpop . (reg reg))
      (max . (reg reg reg))
      (maxu . (reg reg reg))
      (min . (reg reg reg))
      (minu . (reg reg reg))
      (sext.b . (reg reg))
      (sext.h . (reg reg))
      (rol . (reg reg reg))
      (ror . (reg reg reg))
      (orc.b . (reg reg))
    )))

(define rv_zbb-width 32)

;; ====== Helper functions ======

(define (rv_zbb-get-param-count mnemonic)
  (hash-ref rv_zbb-param-count mnemonic #f))

(define (rv_zbb-get-operands mnemonic)
  (hash-ref rv_zbb-operands mnemonic '()))

(define (rv_zbb-get-asm mnemonic)
  (hash-ref rv_zbb-asm mnemonic #f))

(define (rv_zbb-get-operand-types mnemonic)
  (hash-ref rv_zbb-operand-types mnemonic '()))

(define (rv_zbb-get-width) rv_zbb-width)

(define (rv_zbb-exists? mnemonic)
  (hash-has-key? rv_zbb-param-count mnemonic))

(define (rv_zbb-get-field-position mnemonic field)
  (case field
    [(rd) (hash-ref rv_zbb-rd mnemonic #f)]
    [(rs1) (hash-ref rv_zbb-rs1 mnemonic #f)]
    [(rs2) (hash-ref rv_zbb-rs2 mnemonic #f)]
    [else #f]))

(provide
  rv_zbb-rd
  rv_zbb-rs1
  rv_zbb-rs2
  rv_zbb-fields
  rv_zbb-param-count
  rv_zbb-operands
  rv_zbb-asm
  rv_zbb-operand-types
  rv_zbb-width
  rv_zbb-get-param-count
  rv_zbb-get-operands
  rv_zbb-get-asm
  rv_zbb-get-operand-types
  rv_zbb-get-width
  rv_zbb-exists?
  rv_zbb-get-field-position)
