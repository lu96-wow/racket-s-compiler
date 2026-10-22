#lang racket

(define rv64_q_zfa-rd
  (make-immutable-hash
    '(
      (fmvh.x.q . 1)
      (fmvp.q.x . 1)
    )))
(define rv64_q_zfa-rs1
  (make-immutable-hash
    '(
      (fmvh.x.q . 2)
      (fmvp.q.x . 2)
    )))
(define rv64_q_zfa-rs2
  (make-immutable-hash
    '(
      (fmvp.q.x . 3)
    )))

(define rv64_q_zfa-fields '(rd rs1 rs2))

(define rv64_q_zfa-param-count
  (make-immutable-hash
    '(
      (fmvh.x.q . 2)
      (fmvp.q.x . 3)
    )))

(define rv64_q_zfa-operands
  (make-immutable-hash
    '(
      (fmvh.x.q . (rd rs1))
      (fmvp.q.x . (rd rs1 rs2))
    )))

(define rv64_q_zfa-asm
  (make-immutable-hash
    '(
      (fmvh.x.q . "fmvh.x.q rd, rs1")
      (fmvp.q.x . "fmvp.q.x rd, rs1, rs2")
    )))

(define rv64_q_zfa-operand-types
  (make-immutable-hash
    '(
      (fmvh.x.q . (reg reg))
      (fmvp.q.x . (reg reg reg))
    )))

(define rv64_q_zfa-width 32)

;; ====== Helper functions ======

(define (rv64_q_zfa-get-param-count mnemonic)
  (hash-ref rv64_q_zfa-param-count mnemonic #f))

(define (rv64_q_zfa-get-operands mnemonic)
  (hash-ref rv64_q_zfa-operands mnemonic '()))

(define (rv64_q_zfa-get-asm mnemonic)
  (hash-ref rv64_q_zfa-asm mnemonic #f))

(define (rv64_q_zfa-get-operand-types mnemonic)
  (hash-ref rv64_q_zfa-operand-types mnemonic '()))

(define (rv64_q_zfa-get-width) rv64_q_zfa-width)

(define (rv64_q_zfa-exists? mnemonic)
  (hash-has-key? rv64_q_zfa-param-count mnemonic))

(define (rv64_q_zfa-get-field-position mnemonic field)
  (case field
    [(rd) (hash-ref rv64_q_zfa-rd mnemonic #f)]
    [(rs1) (hash-ref rv64_q_zfa-rs1 mnemonic #f)]
    [(rs2) (hash-ref rv64_q_zfa-rs2 mnemonic #f)]
    [else #f]))

(provide
  rv64_q_zfa-rd
  rv64_q_zfa-rs1
  rv64_q_zfa-rs2
  rv64_q_zfa-fields
  rv64_q_zfa-param-count
  rv64_q_zfa-operands
  rv64_q_zfa-asm
  rv64_q_zfa-operand-types
  rv64_q_zfa-width
  rv64_q_zfa-get-param-count
  rv64_q_zfa-get-operands
  rv64_q_zfa-get-asm
  rv64_q_zfa-get-operand-types
  rv64_q_zfa-get-width
  rv64_q_zfa-exists?
  rv64_q_zfa-get-field-position)
