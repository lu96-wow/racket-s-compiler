#lang racket

(define rv_zvbc-vm
  (make-immutable-hash
    '(
      (vclmul.vv . 1)
      (vclmul.vx . 1)
      (vclmulh.vv . 1)
      (vclmulh.vx . 1)
    )))
(define rv_zvbc-vs2
  (make-immutable-hash
    '(
      (vclmul.vv . 2)
      (vclmul.vx . 2)
      (vclmulh.vv . 2)
      (vclmulh.vx . 2)
    )))
(define rv_zvbc-vs1
  (make-immutable-hash
    '(
      (vclmul.vv . 3)
      (vclmulh.vv . 3)
    )))
(define rv_zvbc-vd
  (make-immutable-hash
    '(
      (vclmul.vv . 4)
      (vclmul.vx . 4)
      (vclmulh.vv . 4)
      (vclmulh.vx . 4)
    )))
(define rv_zvbc-rs1
  (make-immutable-hash
    '(
      (vclmul.vx . 3)
      (vclmulh.vx . 3)
    )))

(define rv_zvbc-fields '(vm vs2 vs1 vd rs1))

(define rv_zvbc-param-count
  (make-immutable-hash
    '(
      (vclmul.vv . 4)
      (vclmul.vx . 4)
      (vclmulh.vv . 4)
      (vclmulh.vx . 4)
    )))

(define rv_zvbc-operands
  (make-immutable-hash
    '(
      (vclmul.vv . (vm vs2 vs1 vd))
      (vclmul.vx . (vm vs2 rs1 vd))
      (vclmulh.vv . (vm vs2 vs1 vd))
      (vclmulh.vx . (vm vs2 rs1 vd))
    )))

(define rv_zvbc-asm
  (make-immutable-hash
    '(
      (vclmul.vv . "vclmul.vv vm, vs2, vs1, vd")
      (vclmul.vx . "vclmul.vx vm, vs2, rs1, vd")
      (vclmulh.vv . "vclmulh.vv vm, vs2, vs1, vd")
      (vclmulh.vx . "vclmulh.vx vm, vs2, rs1, vd")
    )))

(define rv_zvbc-operand-types
  (make-immutable-hash
    '(
      (vclmul.vv . (vec vec vec vec))
      (vclmul.vx . (vec vec reg vec))
      (vclmulh.vv . (vec vec vec vec))
      (vclmulh.vx . (vec vec reg vec))
    )))

(define rv_zvbc-width 32)

;; ====== Helper functions ======

(define (rv_zvbc-get-param-count mnemonic)
  (hash-ref rv_zvbc-param-count mnemonic #f))

(define (rv_zvbc-get-operands mnemonic)
  (hash-ref rv_zvbc-operands mnemonic '()))

(define (rv_zvbc-get-asm mnemonic)
  (hash-ref rv_zvbc-asm mnemonic #f))

(define (rv_zvbc-get-operand-types mnemonic)
  (hash-ref rv_zvbc-operand-types mnemonic '()))

(define (rv_zvbc-get-width) rv_zvbc-width)

(define (rv_zvbc-exists? mnemonic)
  (hash-has-key? rv_zvbc-param-count mnemonic))

(define (rv_zvbc-get-field-position mnemonic field)
  (case field
    [(vm) (hash-ref rv_zvbc-vm mnemonic #f)]
    [(vs2) (hash-ref rv_zvbc-vs2 mnemonic #f)]
    [(vs1) (hash-ref rv_zvbc-vs1 mnemonic #f)]
    [(vd) (hash-ref rv_zvbc-vd mnemonic #f)]
    [(rs1) (hash-ref rv_zvbc-rs1 mnemonic #f)]
    [else #f]))

(provide
  rv_zvbc-vm
  rv_zvbc-vs2
  rv_zvbc-vs1
  rv_zvbc-vd
  rv_zvbc-rs1
  rv_zvbc-fields
  rv_zvbc-param-count
  rv_zvbc-operands
  rv_zvbc-asm
  rv_zvbc-operand-types
  rv_zvbc-width
  rv_zvbc-get-param-count
  rv_zvbc-get-operands
  rv_zvbc-get-asm
  rv_zvbc-get-operand-types
  rv_zvbc-get-width
  rv_zvbc-exists?
  rv_zvbc-get-field-position)
