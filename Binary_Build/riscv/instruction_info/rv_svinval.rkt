#lang racket

(define rv_svinval-rs1
  (make-immutable-hash
    '(
      (sinval.vma . 1)
    )))
(define rv_svinval-rs2
  (make-immutable-hash
    '(
      (sinval.vma . 2)
    )))

(define rv_svinval-fields '(rs1 rs2))

(define rv_svinval-param-count
  (make-immutable-hash
    '(
      (sinval.vma . 2)
      (sfence.w.inval . 0)
      (sfence.inval.ir . 0)
    )))

(define rv_svinval-operands
  (make-immutable-hash
    '(
      (sinval.vma . (rs1 rs2))
      (sfence.w.inval . ())
      (sfence.inval.ir . ())
    )))

(define rv_svinval-asm
  (make-immutable-hash
    '(
      (sinval.vma . "sinval.vma rs1, rs2")
      (sfence.w.inval . "sfence.w.inval")
      (sfence.inval.ir . "sfence.inval.ir")
    )))

(define rv_svinval-operand-types
  (make-immutable-hash
    '(
      (sinval.vma . (reg reg))
      (sfence.w.inval . ())
      (sfence.inval.ir . ())
    )))

(define rv_svinval-width 32)

;; ====== Helper functions ======

(define (rv_svinval-get-param-count mnemonic)
  (hash-ref rv_svinval-param-count mnemonic #f))

(define (rv_svinval-get-operands mnemonic)
  (hash-ref rv_svinval-operands mnemonic '()))

(define (rv_svinval-get-asm mnemonic)
  (hash-ref rv_svinval-asm mnemonic #f))

(define (rv_svinval-get-operand-types mnemonic)
  (hash-ref rv_svinval-operand-types mnemonic '()))

(define (rv_svinval-get-width) rv_svinval-width)

(define (rv_svinval-exists? mnemonic)
  (hash-has-key? rv_svinval-param-count mnemonic))

(define (rv_svinval-get-field-position mnemonic field)
  (case field
    [(rs1) (hash-ref rv_svinval-rs1 mnemonic #f)]
    [(rs2) (hash-ref rv_svinval-rs2 mnemonic #f)]
    [else #f]))

(provide
  rv_svinval-rs1
  rv_svinval-rs2
  rv_svinval-fields
  rv_svinval-param-count
  rv_svinval-operands
  rv_svinval-asm
  rv_svinval-operand-types
  rv_svinval-width
  rv_svinval-get-param-count
  rv_svinval-get-operands
  rv_svinval-get-asm
  rv_svinval-get-operand-types
  rv_svinval-get-width
  rv_svinval-exists?
  rv_svinval-get-field-position)
