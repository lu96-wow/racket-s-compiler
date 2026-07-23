#lang racket

(define rv_zknh-rd
  (make-immutable-hash
    '(
      (sha256sum0 . 1)
      (sha256sum1 . 1)
      (sha256sig0 . 1)
      (sha256sig1 . 1)
    )))
(define rv_zknh-rs1
  (make-immutable-hash
    '(
      (sha256sum0 . 2)
      (sha256sum1 . 2)
      (sha256sig0 . 2)
      (sha256sig1 . 2)
    )))

(define rv_zknh-fields '(rd rs1))

(define rv_zknh-param-count
  (make-immutable-hash
    '(
      (sha256sum0 . 2)
      (sha256sum1 . 2)
      (sha256sig0 . 2)
      (sha256sig1 . 2)
    )))

(define rv_zknh-operands
  (make-immutable-hash
    '(
      (sha256sum0 . (rd rs1))
      (sha256sum1 . (rd rs1))
      (sha256sig0 . (rd rs1))
      (sha256sig1 . (rd rs1))
    )))

(define rv_zknh-asm
  (make-immutable-hash
    '(
      (sha256sum0 . "sha256sum0 rd, rs1")
      (sha256sum1 . "sha256sum1 rd, rs1")
      (sha256sig0 . "sha256sig0 rd, rs1")
      (sha256sig1 . "sha256sig1 rd, rs1")
    )))

(define rv_zknh-operand-types
  (make-immutable-hash
    '(
      (sha256sum0 . (reg reg))
      (sha256sum1 . (reg reg))
      (sha256sig0 . (reg reg))
      (sha256sig1 . (reg reg))
    )))

(define rv_zknh-width 32)

;; ====== Helper functions ======

(define (rv_zknh-get-param-count mnemonic)
  (hash-ref rv_zknh-param-count mnemonic #f))

(define (rv_zknh-get-operands mnemonic)
  (hash-ref rv_zknh-operands mnemonic '()))

(define (rv_zknh-get-asm mnemonic)
  (hash-ref rv_zknh-asm mnemonic #f))

(define (rv_zknh-get-operand-types mnemonic)
  (hash-ref rv_zknh-operand-types mnemonic '()))

(define (rv_zknh-get-width) rv_zknh-width)

(define (rv_zknh-exists? mnemonic)
  (hash-has-key? rv_zknh-param-count mnemonic))

(define (rv_zknh-get-field-position mnemonic field)
  (case field
    [(rd) (hash-ref rv_zknh-rd mnemonic #f)]
    [(rs1) (hash-ref rv_zknh-rs1 mnemonic #f)]
    [else #f]))

(provide
  rv_zknh-rd
  rv_zknh-rs1
  rv_zknh-fields
  rv_zknh-param-count
  rv_zknh-operands
  rv_zknh-asm
  rv_zknh-operand-types
  rv_zknh-width
  rv_zknh-get-param-count
  rv_zknh-get-operands
  rv_zknh-get-asm
  rv_zknh-get-operand-types
  rv_zknh-get-width
  rv_zknh-exists?
  rv_zknh-get-field-position)
