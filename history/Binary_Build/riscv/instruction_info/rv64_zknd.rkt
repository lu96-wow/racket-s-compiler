#lang racket

(define rv64_zknd-rd
  (make-immutable-hash
    '(
      (aes64dsm . 1)
      (aes64ds . 1)
      (aes64ks1i . 1)
      (aes64im . 1)
      (aes64ks2 . 1)
    )))
(define rv64_zknd-rs1
  (make-immutable-hash
    '(
      (aes64dsm . 2)
      (aes64ds . 2)
      (aes64ks1i . 2)
      (aes64im . 2)
      (aes64ks2 . 2)
    )))
(define rv64_zknd-rs2
  (make-immutable-hash
    '(
      (aes64dsm . 3)
      (aes64ds . 3)
      (aes64ks2 . 3)
    )))
(define rv64_zknd-rnum
  (make-immutable-hash
    '(
      (aes64ks1i . 3)
    )))

(define rv64_zknd-fields '(rd rs1 rs2 rnum))

(define rv64_zknd-param-count
  (make-immutable-hash
    '(
      (aes64dsm . 3)
      (aes64ds . 3)
      (aes64ks1i . 3)
      (aes64im . 2)
      (aes64ks2 . 3)
    )))

(define rv64_zknd-operands
  (make-immutable-hash
    '(
      (aes64dsm . (rd rs1 rs2))
      (aes64ds . (rd rs1 rs2))
      (aes64ks1i . (rd rs1 rnum))
      (aes64im . (rd rs1))
      (aes64ks2 . (rd rs1 rs2))
    )))

(define rv64_zknd-asm
  (make-immutable-hash
    '(
      (aes64dsm . "aes64dsm rd, rs1, rs2")
      (aes64ds . "aes64ds rd, rs1, rs2")
      (aes64ks1i . "aes64ks1i rd, rs1, rnum")
      (aes64im . "aes64im rd, rs1")
      (aes64ks2 . "aes64ks2 rd, rs1, rs2")
    )))

(define rv64_zknd-operand-types
  (make-immutable-hash
    '(
      (aes64dsm . (reg reg reg))
      (aes64ds . (reg reg reg))
      (aes64ks1i . (reg reg imm))
      (aes64im . (reg reg))
      (aes64ks2 . (reg reg reg))
    )))

(define rv64_zknd-width 32)

;; ====== Helper functions ======

(define (rv64_zknd-get-param-count mnemonic)
  (hash-ref rv64_zknd-param-count mnemonic #f))

(define (rv64_zknd-get-operands mnemonic)
  (hash-ref rv64_zknd-operands mnemonic '()))

(define (rv64_zknd-get-asm mnemonic)
  (hash-ref rv64_zknd-asm mnemonic #f))

(define (rv64_zknd-get-operand-types mnemonic)
  (hash-ref rv64_zknd-operand-types mnemonic '()))

(define (rv64_zknd-get-width) rv64_zknd-width)

(define (rv64_zknd-exists? mnemonic)
  (hash-has-key? rv64_zknd-param-count mnemonic))

(define (rv64_zknd-get-field-position mnemonic field)
  (case field
    [(rd) (hash-ref rv64_zknd-rd mnemonic #f)]
    [(rs1) (hash-ref rv64_zknd-rs1 mnemonic #f)]
    [(rs2) (hash-ref rv64_zknd-rs2 mnemonic #f)]
    [(rnum) (hash-ref rv64_zknd-rnum mnemonic #f)]
    [else #f]))

(provide
  rv64_zknd-rd
  rv64_zknd-rs1
  rv64_zknd-rs2
  rv64_zknd-rnum
  rv64_zknd-fields
  rv64_zknd-param-count
  rv64_zknd-operands
  rv64_zknd-asm
  rv64_zknd-operand-types
  rv64_zknd-width
  rv64_zknd-get-param-count
  rv64_zknd-get-operands
  rv64_zknd-get-asm
  rv64_zknd-get-operand-types
  rv64_zknd-get-width
  rv64_zknd-exists?
  rv64_zknd-get-field-position)
