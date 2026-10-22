#lang racket

(define rv_s-rs1
  (make-immutable-hash
    '(
      (sfence.vma . 1)
    )))
(define rv_s-rs2
  (make-immutable-hash
    '(
      (sfence.vma . 2)
    )))

(define rv_s-fields '(rs1 rs2))

(define rv_s-param-count
  (make-immutable-hash
    '(
      (sfence.vma . 2)
      (sret . 0)
    )))

(define rv_s-operands
  (make-immutable-hash
    '(
      (sfence.vma . (rs1 rs2))
      (sret . ())
    )))

(define rv_s-asm
  (make-immutable-hash
    '(
      (sfence.vma . "sfence.vma rs1, rs2")
      (sret . "sret")
    )))

(define rv_s-operand-types
  (make-immutable-hash
    '(
      (sfence.vma . (reg reg))
      (sret . ())
    )))

(define rv_s-width 32)

;; ====== Helper functions ======

(define (rv_s-get-param-count mnemonic)
  (hash-ref rv_s-param-count mnemonic #f))

(define (rv_s-get-operands mnemonic)
  (hash-ref rv_s-operands mnemonic '()))

(define (rv_s-get-asm mnemonic)
  (hash-ref rv_s-asm mnemonic #f))

(define (rv_s-get-operand-types mnemonic)
  (hash-ref rv_s-operand-types mnemonic '()))

(define (rv_s-get-width) rv_s-width)

(define (rv_s-exists? mnemonic)
  (hash-has-key? rv_s-param-count mnemonic))

(define (rv_s-get-field-position mnemonic field)
  (case field
    [(rs1) (hash-ref rv_s-rs1 mnemonic #f)]
    [(rs2) (hash-ref rv_s-rs2 mnemonic #f)]
    [else #f]))

(provide
  rv_s-rs1
  rv_s-rs2
  rv_s-fields
  rv_s-param-count
  rv_s-operands
  rv_s-asm
  rv_s-operand-types
  rv_s-width
  rv_s-get-param-count
  rv_s-get-operands
  rv_s-get-asm
  rv_s-get-operand-types
  rv_s-get-width
  rv_s-exists?
  rv_s-get-field-position)
