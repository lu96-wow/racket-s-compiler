#lang racket

(define rv64_m-rd
  (make-immutable-hash
    '(
      (mulw . 1)
      (divw . 1)
      (divuw . 1)
      (remw . 1)
      (remuw . 1)
    )))
(define rv64_m-rs1
  (make-immutable-hash
    '(
      (mulw . 2)
      (divw . 2)
      (divuw . 2)
      (remw . 2)
      (remuw . 2)
    )))
(define rv64_m-rs2
  (make-immutable-hash
    '(
      (mulw . 3)
      (divw . 3)
      (divuw . 3)
      (remw . 3)
      (remuw . 3)
    )))

(define rv64_m-fields '(rd rs1 rs2))

(define rv64_m-param-count
  (make-immutable-hash
    '(
      (mulw . 3)
      (divw . 3)
      (divuw . 3)
      (remw . 3)
      (remuw . 3)
    )))

(define rv64_m-operands
  (make-immutable-hash
    '(
      (mulw . (rd rs1 rs2))
      (divw . (rd rs1 rs2))
      (divuw . (rd rs1 rs2))
      (remw . (rd rs1 rs2))
      (remuw . (rd rs1 rs2))
    )))

(define rv64_m-asm
  (make-immutable-hash
    '(
      (mulw . "mulw rd, rs1, rs2")
      (divw . "divw rd, rs1, rs2")
      (divuw . "divuw rd, rs1, rs2")
      (remw . "remw rd, rs1, rs2")
      (remuw . "remuw rd, rs1, rs2")
    )))

(define rv64_m-operand-types
  (make-immutable-hash
    '(
      (mulw . (reg reg reg))
      (divw . (reg reg reg))
      (divuw . (reg reg reg))
      (remw . (reg reg reg))
      (remuw . (reg reg reg))
    )))

(define rv64_m-width 32)

;; ====== Helper functions ======

(define (rv64_m-get-param-count mnemonic)
  (hash-ref rv64_m-param-count mnemonic #f))

(define (rv64_m-get-operands mnemonic)
  (hash-ref rv64_m-operands mnemonic '()))

(define (rv64_m-get-asm mnemonic)
  (hash-ref rv64_m-asm mnemonic #f))

(define (rv64_m-get-operand-types mnemonic)
  (hash-ref rv64_m-operand-types mnemonic '()))

(define (rv64_m-get-width) rv64_m-width)

(define (rv64_m-exists? mnemonic)
  (hash-has-key? rv64_m-param-count mnemonic))

(define (rv64_m-get-field-position mnemonic field)
  (case field
    [(rd) (hash-ref rv64_m-rd mnemonic #f)]
    [(rs1) (hash-ref rv64_m-rs1 mnemonic #f)]
    [(rs2) (hash-ref rv64_m-rs2 mnemonic #f)]
    [else #f]))

(provide
  rv64_m-rd
  rv64_m-rs1
  rv64_m-rs2
  rv64_m-fields
  rv64_m-param-count
  rv64_m-operands
  rv64_m-asm
  rv64_m-operand-types
  rv64_m-width
  rv64_m-get-param-count
  rv64_m-get-operands
  rv64_m-get-asm
  rv64_m-get-operand-types
  rv64_m-get-width
  rv64_m-exists?
  rv64_m-get-field-position)
