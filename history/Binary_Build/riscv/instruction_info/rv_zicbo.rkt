#lang racket

(define rv_zicbo-rs1
  (make-immutable-hash
    '(
      (cbo.clean . 1)
      (cbo.flush . 1)
      (cbo.inval . 1)
      (cbo.zero . 1)
    )))

(define rv_zicbo-fields '(rs1))

(define rv_zicbo-param-count
  (make-immutable-hash
    '(
      (cbo.clean . 1)
      (cbo.flush . 1)
      (cbo.inval . 1)
      (cbo.zero . 1)
    )))

(define rv_zicbo-operands
  (make-immutable-hash
    '(
      (cbo.clean . (rs1))
      (cbo.flush . (rs1))
      (cbo.inval . (rs1))
      (cbo.zero . (rs1))
    )))

(define rv_zicbo-asm
  (make-immutable-hash
    '(
      (cbo.clean . "cbo.clean rs1")
      (cbo.flush . "cbo.flush rs1")
      (cbo.inval . "cbo.inval rs1")
      (cbo.zero . "cbo.zero rs1")
    )))

(define rv_zicbo-operand-types
  (make-immutable-hash
    '(
      (cbo.clean . (reg))
      (cbo.flush . (reg))
      (cbo.inval . (reg))
      (cbo.zero . (reg))
    )))

(define rv_zicbo-width 32)

;; ====== Helper functions ======

(define (rv_zicbo-get-param-count mnemonic)
  (hash-ref rv_zicbo-param-count mnemonic #f))

(define (rv_zicbo-get-operands mnemonic)
  (hash-ref rv_zicbo-operands mnemonic '()))

(define (rv_zicbo-get-asm mnemonic)
  (hash-ref rv_zicbo-asm mnemonic #f))

(define (rv_zicbo-get-operand-types mnemonic)
  (hash-ref rv_zicbo-operand-types mnemonic '()))

(define (rv_zicbo-get-width) rv_zicbo-width)

(define (rv_zicbo-exists? mnemonic)
  (hash-has-key? rv_zicbo-param-count mnemonic))

(define (rv_zicbo-get-field-position mnemonic field)
  (case field
    [(rs1) (hash-ref rv_zicbo-rs1 mnemonic #f)]
    [else #f]))

(provide
  rv_zicbo-rs1
  rv_zicbo-fields
  rv_zicbo-param-count
  rv_zicbo-operands
  rv_zicbo-asm
  rv_zicbo-operand-types
  rv_zicbo-width
  rv_zicbo-get-param-count
  rv_zicbo-get-operands
  rv_zicbo-get-asm
  rv_zicbo-get-operand-types
  rv_zicbo-get-width
  rv_zicbo-exists?
  rv_zicbo-get-field-position)
