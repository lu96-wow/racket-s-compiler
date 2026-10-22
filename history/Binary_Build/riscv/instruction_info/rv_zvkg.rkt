#lang racket

(define rv_zvkg-vs2
  (make-immutable-hash
    '(
      (vgmul.vv . 1)
      (vghsh.vv . 1)
    )))
(define rv_zvkg-vd
  (make-immutable-hash
    '(
      (vgmul.vv . 2)
      (vghsh.vv . 3)
    )))
(define rv_zvkg-vs1
  (make-immutable-hash
    '(
      (vghsh.vv . 2)
    )))

(define rv_zvkg-fields '(vs2 vd vs1))

(define rv_zvkg-param-count
  (make-immutable-hash
    '(
      (vgmul.vv . 2)
      (vghsh.vv . 3)
    )))

(define rv_zvkg-operands
  (make-immutable-hash
    '(
      (vgmul.vv . (vs2 vd))
      (vghsh.vv . (vs2 vs1 vd))
    )))

(define rv_zvkg-asm
  (make-immutable-hash
    '(
      (vgmul.vv . "vgmul.vv vs2, vd")
      (vghsh.vv . "vghsh.vv vs2, vs1, vd")
    )))

(define rv_zvkg-operand-types
  (make-immutable-hash
    '(
      (vgmul.vv . (vec vec))
      (vghsh.vv . (vec vec vec))
    )))

(define rv_zvkg-width 32)

;; ====== Helper functions ======

(define (rv_zvkg-get-param-count mnemonic)
  (hash-ref rv_zvkg-param-count mnemonic #f))

(define (rv_zvkg-get-operands mnemonic)
  (hash-ref rv_zvkg-operands mnemonic '()))

(define (rv_zvkg-get-asm mnemonic)
  (hash-ref rv_zvkg-asm mnemonic #f))

(define (rv_zvkg-get-operand-types mnemonic)
  (hash-ref rv_zvkg-operand-types mnemonic '()))

(define (rv_zvkg-get-width) rv_zvkg-width)

(define (rv_zvkg-exists? mnemonic)
  (hash-has-key? rv_zvkg-param-count mnemonic))

(define (rv_zvkg-get-field-position mnemonic field)
  (case field
    [(vs2) (hash-ref rv_zvkg-vs2 mnemonic #f)]
    [(vd) (hash-ref rv_zvkg-vd mnemonic #f)]
    [(vs1) (hash-ref rv_zvkg-vs1 mnemonic #f)]
    [else #f]))

(provide
  rv_zvkg-vs2
  rv_zvkg-vd
  rv_zvkg-vs1
  rv_zvkg-fields
  rv_zvkg-param-count
  rv_zvkg-operands
  rv_zvkg-asm
  rv_zvkg-operand-types
  rv_zvkg-width
  rv_zvkg-get-param-count
  rv_zvkg-get-operands
  rv_zvkg-get-asm
  rv_zvkg-get-operand-types
  rv_zvkg-get-width
  rv_zvkg-exists?
  rv_zvkg-get-field-position)
