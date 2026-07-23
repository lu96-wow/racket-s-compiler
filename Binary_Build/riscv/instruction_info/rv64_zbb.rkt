#lang racket

(define rv64_zbb-rd
  (make-immutable-hash
    '(
      (clzw . 1)
      (ctzw . 1)
      (cpopw . 1)
      (rolw . 1)
      (rorw . 1)
      (roriw . 1)
      (rori . 1)
      (rev8 . 1)
    )))
(define rv64_zbb-rs1
  (make-immutable-hash
    '(
      (clzw . 2)
      (ctzw . 2)
      (cpopw . 2)
      (rolw . 2)
      (rorw . 2)
      (roriw . 2)
      (rori . 2)
      (rev8 . 2)
    )))
(define rv64_zbb-rs2
  (make-immutable-hash
    '(
      (rolw . 3)
      (rorw . 3)
    )))
(define rv64_zbb-shamtw
  (make-immutable-hash
    '(
      (roriw . 3)
    )))
(define rv64_zbb-shamtd
  (make-immutable-hash
    '(
      (rori . 3)
    )))

(define rv64_zbb-fields '(rd rs1 rs2 shamtw shamtd))

(define rv64_zbb-param-count
  (make-immutable-hash
    '(
      (clzw . 2)
      (ctzw . 2)
      (cpopw . 2)
      (rolw . 3)
      (rorw . 3)
      (roriw . 3)
      (rori . 3)
      (rev8 . 2)
    )))

(define rv64_zbb-operands
  (make-immutable-hash
    '(
      (clzw . (rd rs1))
      (ctzw . (rd rs1))
      (cpopw . (rd rs1))
      (rolw . (rd rs1 rs2))
      (rorw . (rd rs1 rs2))
      (roriw . (rd rs1 shamtw))
      (rori . (rd rs1 shamtd))
      (rev8 . (rd rs1))
    )))

(define rv64_zbb-asm
  (make-immutable-hash
    '(
      (clzw . "clzw rd, rs1")
      (ctzw . "ctzw rd, rs1")
      (cpopw . "cpopw rd, rs1")
      (rolw . "rolw rd, rs1, rs2")
      (rorw . "rorw rd, rs1, rs2")
      (roriw . "roriw rd, rs1, shamtw")
      (rori . "rori rd, rs1, shamtd")
      (rev8 . "rev8 rd, rs1")
    )))

(define rv64_zbb-operand-types
  (make-immutable-hash
    '(
      (clzw . (reg reg))
      (ctzw . (reg reg))
      (cpopw . (reg reg))
      (rolw . (reg reg reg))
      (rorw . (reg reg reg))
      (roriw . (reg reg imm))
      (rori . (reg reg imm))
      (rev8 . (reg reg))
    )))

(define rv64_zbb-width 32)

;; ====== Helper functions ======

(define (rv64_zbb-get-param-count mnemonic)
  (hash-ref rv64_zbb-param-count mnemonic #f))

(define (rv64_zbb-get-operands mnemonic)
  (hash-ref rv64_zbb-operands mnemonic '()))

(define (rv64_zbb-get-asm mnemonic)
  (hash-ref rv64_zbb-asm mnemonic #f))

(define (rv64_zbb-get-operand-types mnemonic)
  (hash-ref rv64_zbb-operand-types mnemonic '()))

(define (rv64_zbb-get-width) rv64_zbb-width)

(define (rv64_zbb-exists? mnemonic)
  (hash-has-key? rv64_zbb-param-count mnemonic))

(define (rv64_zbb-get-field-position mnemonic field)
  (case field
    [(rd) (hash-ref rv64_zbb-rd mnemonic #f)]
    [(rs1) (hash-ref rv64_zbb-rs1 mnemonic #f)]
    [(rs2) (hash-ref rv64_zbb-rs2 mnemonic #f)]
    [(shamtw) (hash-ref rv64_zbb-shamtw mnemonic #f)]
    [(shamtd) (hash-ref rv64_zbb-shamtd mnemonic #f)]
    [else #f]))

(provide
  rv64_zbb-rd
  rv64_zbb-rs1
  rv64_zbb-rs2
  rv64_zbb-shamtw
  rv64_zbb-shamtd
  rv64_zbb-fields
  rv64_zbb-param-count
  rv64_zbb-operands
  rv64_zbb-asm
  rv64_zbb-operand-types
  rv64_zbb-width
  rv64_zbb-get-param-count
  rv64_zbb-get-operands
  rv64_zbb-get-asm
  rv64_zbb-get-operand-types
  rv64_zbb-get-width
  rv64_zbb-exists?
  rv64_zbb-get-field-position)
