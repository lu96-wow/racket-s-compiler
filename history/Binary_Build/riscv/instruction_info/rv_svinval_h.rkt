#lang racket

(define rv_svinval_h-rs1
  (make-immutable-hash
    '(
      (hinval.vvma . 1)
      (hinval.gvma . 1)
    )))
(define rv_svinval_h-rs2
  (make-immutable-hash
    '(
      (hinval.vvma . 2)
      (hinval.gvma . 2)
    )))

(define rv_svinval_h-fields '(rs1 rs2))

(define rv_svinval_h-param-count
  (make-immutable-hash
    '(
      (hinval.vvma . 2)
      (hinval.gvma . 2)
    )))

(define rv_svinval_h-operands
  (make-immutable-hash
    '(
      (hinval.vvma . (rs1 rs2))
      (hinval.gvma . (rs1 rs2))
    )))

(define rv_svinval_h-asm
  (make-immutable-hash
    '(
      (hinval.vvma . "hinval.vvma rs1, rs2")
      (hinval.gvma . "hinval.gvma rs1, rs2")
    )))

(define rv_svinval_h-operand-types
  (make-immutable-hash
    '(
      (hinval.vvma . (reg reg))
      (hinval.gvma . (reg reg))
    )))

(define rv_svinval_h-width 32)

;; ====== Helper functions ======

(define (rv_svinval_h-get-param-count mnemonic)
  (hash-ref rv_svinval_h-param-count mnemonic #f))

(define (rv_svinval_h-get-operands mnemonic)
  (hash-ref rv_svinval_h-operands mnemonic '()))

(define (rv_svinval_h-get-asm mnemonic)
  (hash-ref rv_svinval_h-asm mnemonic #f))

(define (rv_svinval_h-get-operand-types mnemonic)
  (hash-ref rv_svinval_h-operand-types mnemonic '()))

(define (rv_svinval_h-get-width) rv_svinval_h-width)

(define (rv_svinval_h-exists? mnemonic)
  (hash-has-key? rv_svinval_h-param-count mnemonic))

(define (rv_svinval_h-get-field-position mnemonic field)
  (case field
    [(rs1) (hash-ref rv_svinval_h-rs1 mnemonic #f)]
    [(rs2) (hash-ref rv_svinval_h-rs2 mnemonic #f)]
    [else #f]))

(provide
  rv_svinval_h-rs1
  rv_svinval_h-rs2
  rv_svinval_h-fields
  rv_svinval_h-param-count
  rv_svinval_h-operands
  rv_svinval_h-asm
  rv_svinval_h-operand-types
  rv_svinval_h-width
  rv_svinval_h-get-param-count
  rv_svinval_h-get-operands
  rv_svinval_h-get-asm
  rv_svinval_h-get-operand-types
  rv_svinval_h-get-width
  rv_svinval_h-exists?
  rv_svinval_h-get-field-position)
