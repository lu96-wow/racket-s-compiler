#lang racket

(define rv_zifencei-imm12
  (make-immutable-hash
    '(
      (fence.i . 1)
    )))
(define rv_zifencei-rs1
  (make-immutable-hash
    '(
      (fence.i . 2)
    )))
(define rv_zifencei-rd
  (make-immutable-hash
    '(
      (fence.i . 3)
    )))

(define rv_zifencei-fields '(imm12 rs1 rd))

(define rv_zifencei-param-count
  (make-immutable-hash
    '(
      (fence.i . 3)
    )))

(define rv_zifencei-operands
  (make-immutable-hash
    '(
      (fence.i . (imm12 rs1 rd))
    )))

(define rv_zifencei-asm
  (make-immutable-hash
    '(
      (fence.i . "fence.i imm12, rs1, rd")
    )))

(define rv_zifencei-operand-types
  (make-immutable-hash
    '(
      (fence.i . (imm reg reg))
    )))

(define rv_zifencei-width 32)

;; ====== Helper functions ======

(define (rv_zifencei-get-param-count mnemonic)
  (hash-ref rv_zifencei-param-count mnemonic #f))

(define (rv_zifencei-get-operands mnemonic)
  (hash-ref rv_zifencei-operands mnemonic '()))

(define (rv_zifencei-get-asm mnemonic)
  (hash-ref rv_zifencei-asm mnemonic #f))

(define (rv_zifencei-get-operand-types mnemonic)
  (hash-ref rv_zifencei-operand-types mnemonic '()))

(define (rv_zifencei-get-width) rv_zifencei-width)

(define (rv_zifencei-exists? mnemonic)
  (hash-has-key? rv_zifencei-param-count mnemonic))

(define (rv_zifencei-get-field-position mnemonic field)
  (case field
    [(imm12) (hash-ref rv_zifencei-imm12 mnemonic #f)]
    [(rs1) (hash-ref rv_zifencei-rs1 mnemonic #f)]
    [(rd) (hash-ref rv_zifencei-rd mnemonic #f)]
    [else #f]))

(provide
  rv_zifencei-imm12
  rv_zifencei-rs1
  rv_zifencei-rd
  rv_zifencei-fields
  rv_zifencei-param-count
  rv_zifencei-operands
  rv_zifencei-asm
  rv_zifencei-operand-types
  rv_zifencei-width
  rv_zifencei-get-param-count
  rv_zifencei-get-operands
  rv_zifencei-get-asm
  rv_zifencei-get-operand-types
  rv_zifencei-get-width
  rv_zifencei-exists?
  rv_zifencei-get-field-position)
