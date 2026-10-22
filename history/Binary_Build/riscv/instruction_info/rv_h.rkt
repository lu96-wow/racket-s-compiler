#lang racket

(define rv_h-rs1
  (make-immutable-hash
    '(
      (hfence.vvma . 1)
      (hfence.gvma . 1)
      (hlv.b . 2)
      (hlv.bu . 2)
      (hlv.h . 2)
      (hlv.hu . 2)
      (hlvx.hu . 2)
      (hlv.w . 2)
      (hlvx.wu . 2)
      (hsv.b . 1)
      (hsv.h . 1)
      (hsv.w . 1)
    )))
(define rv_h-rs2
  (make-immutable-hash
    '(
      (hfence.vvma . 2)
      (hfence.gvma . 2)
      (hsv.b . 2)
      (hsv.h . 2)
      (hsv.w . 2)
    )))
(define rv_h-rd
  (make-immutable-hash
    '(
      (hlv.b . 1)
      (hlv.bu . 1)
      (hlv.h . 1)
      (hlv.hu . 1)
      (hlvx.hu . 1)
      (hlv.w . 1)
      (hlvx.wu . 1)
    )))

(define rv_h-fields '(rs1 rs2 rd))

(define rv_h-param-count
  (make-immutable-hash
    '(
      (hfence.vvma . 2)
      (hfence.gvma . 2)
      (hlv.b . 2)
      (hlv.bu . 2)
      (hlv.h . 2)
      (hlv.hu . 2)
      (hlvx.hu . 2)
      (hlv.w . 2)
      (hlvx.wu . 2)
      (hsv.b . 2)
      (hsv.h . 2)
      (hsv.w . 2)
    )))

(define rv_h-operands
  (make-immutable-hash
    '(
      (hfence.vvma . (rs1 rs2))
      (hfence.gvma . (rs1 rs2))
      (hlv.b . (rd rs1))
      (hlv.bu . (rd rs1))
      (hlv.h . (rd rs1))
      (hlv.hu . (rd rs1))
      (hlvx.hu . (rd rs1))
      (hlv.w . (rd rs1))
      (hlvx.wu . (rd rs1))
      (hsv.b . (rs1 rs2))
      (hsv.h . (rs1 rs2))
      (hsv.w . (rs1 rs2))
    )))

(define rv_h-asm
  (make-immutable-hash
    '(
      (hfence.vvma . "hfence.vvma rs1, rs2")
      (hfence.gvma . "hfence.gvma rs1, rs2")
      (hlv.b . "hlv.b rd, rs1")
      (hlv.bu . "hlv.bu rd, rs1")
      (hlv.h . "hlv.h rd, rs1")
      (hlv.hu . "hlv.hu rd, rs1")
      (hlvx.hu . "hlvx.hu rd, rs1")
      (hlv.w . "hlv.w rd, rs1")
      (hlvx.wu . "hlvx.wu rd, rs1")
      (hsv.b . "hsv.b rs1, rs2")
      (hsv.h . "hsv.h rs1, rs2")
      (hsv.w . "hsv.w rs1, rs2")
    )))

(define rv_h-operand-types
  (make-immutable-hash
    '(
      (hfence.vvma . (reg reg))
      (hfence.gvma . (reg reg))
      (hlv.b . (reg reg))
      (hlv.bu . (reg reg))
      (hlv.h . (reg reg))
      (hlv.hu . (reg reg))
      (hlvx.hu . (reg reg))
      (hlv.w . (reg reg))
      (hlvx.wu . (reg reg))
      (hsv.b . (reg reg))
      (hsv.h . (reg reg))
      (hsv.w . (reg reg))
    )))

(define rv_h-width 32)

;; ====== Helper functions ======

(define (rv_h-get-param-count mnemonic)
  (hash-ref rv_h-param-count mnemonic #f))

(define (rv_h-get-operands mnemonic)
  (hash-ref rv_h-operands mnemonic '()))

(define (rv_h-get-asm mnemonic)
  (hash-ref rv_h-asm mnemonic #f))

(define (rv_h-get-operand-types mnemonic)
  (hash-ref rv_h-operand-types mnemonic '()))

(define (rv_h-get-width) rv_h-width)

(define (rv_h-exists? mnemonic)
  (hash-has-key? rv_h-param-count mnemonic))

(define (rv_h-get-field-position mnemonic field)
  (case field
    [(rs1) (hash-ref rv_h-rs1 mnemonic #f)]
    [(rs2) (hash-ref rv_h-rs2 mnemonic #f)]
    [(rd) (hash-ref rv_h-rd mnemonic #f)]
    [else #f]))

(provide
  rv_h-rs1
  rv_h-rs2
  rv_h-rd
  rv_h-fields
  rv_h-param-count
  rv_h-operands
  rv_h-asm
  rv_h-operand-types
  rv_h-width
  rv_h-get-param-count
  rv_h-get-operands
  rv_h-get-asm
  rv_h-get-operand-types
  rv_h-get-width
  rv_h-exists?
  rv_h-get-field-position)
