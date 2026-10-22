#lang racket

(define rv_zicond-rd
  (make-immutable-hash
    '(
      (czero.eqz . 1)
      (czero.nez . 1)
    )))
(define rv_zicond-rs1
  (make-immutable-hash
    '(
      (czero.eqz . 2)
      (czero.nez . 2)
    )))
(define rv_zicond-rs2
  (make-immutable-hash
    '(
      (czero.eqz . 3)
      (czero.nez . 3)
    )))

(define rv_zicond-fields '(rd rs1 rs2))

(define rv_zicond-param-count
  (make-immutable-hash
    '(
      (czero.eqz . 3)
      (czero.nez . 3)
    )))

(define rv_zicond-operands
  (make-immutable-hash
    '(
      (czero.eqz . (rd rs1 rs2))
      (czero.nez . (rd rs1 rs2))
    )))

(define rv_zicond-asm
  (make-immutable-hash
    '(
      (czero.eqz . "czero.eqz rd, rs1, rs2")
      (czero.nez . "czero.nez rd, rs1, rs2")
    )))

(define rv_zicond-operand-types
  (make-immutable-hash
    '(
      (czero.eqz . (reg reg reg))
      (czero.nez . (reg reg reg))
    )))

(define rv_zicond-width 32)

;; ====== Helper functions ======

(define (rv_zicond-get-param-count mnemonic)
  (hash-ref rv_zicond-param-count mnemonic #f))

(define (rv_zicond-get-operands mnemonic)
  (hash-ref rv_zicond-operands mnemonic '()))

(define (rv_zicond-get-asm mnemonic)
  (hash-ref rv_zicond-asm mnemonic #f))

(define (rv_zicond-get-operand-types mnemonic)
  (hash-ref rv_zicond-operand-types mnemonic '()))

(define (rv_zicond-get-width) rv_zicond-width)

(define (rv_zicond-exists? mnemonic)
  (hash-has-key? rv_zicond-param-count mnemonic))

(define (rv_zicond-get-field-position mnemonic field)
  (case field
    [(rd) (hash-ref rv_zicond-rd mnemonic #f)]
    [(rs1) (hash-ref rv_zicond-rs1 mnemonic #f)]
    [(rs2) (hash-ref rv_zicond-rs2 mnemonic #f)]
    [else #f]))

(provide
  rv_zicond-rd
  rv_zicond-rs1
  rv_zicond-rs2
  rv_zicond-fields
  rv_zicond-param-count
  rv_zicond-operands
  rv_zicond-asm
  rv_zicond-operand-types
  rv_zicond-width
  rv_zicond-get-param-count
  rv_zicond-get-operands
  rv_zicond-get-asm
  rv_zicond-get-operand-types
  rv_zicond-get-width
  rv_zicond-exists?
  rv_zicond-get-field-position)
