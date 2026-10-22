#lang racket

(define rv_zvksh-vs2
  (make-immutable-hash
    '(
      (vsm3c.vi . 1)
      (vsm3me.vv . 1)
    )))
(define rv_zvksh-zimm5
  (make-immutable-hash
    '(
      (vsm3c.vi . 2)
    )))
(define rv_zvksh-vd
  (make-immutable-hash
    '(
      (vsm3c.vi . 3)
      (vsm3me.vv . 3)
    )))
(define rv_zvksh-vs1
  (make-immutable-hash
    '(
      (vsm3me.vv . 2)
    )))

(define rv_zvksh-fields '(vs2 zimm5 vd vs1))

(define rv_zvksh-param-count
  (make-immutable-hash
    '(
      (vsm3c.vi . 3)
      (vsm3me.vv . 3)
    )))

(define rv_zvksh-operands
  (make-immutable-hash
    '(
      (vsm3c.vi . (vs2 zimm5 vd))
      (vsm3me.vv . (vs2 vs1 vd))
    )))

(define rv_zvksh-asm
  (make-immutable-hash
    '(
      (vsm3c.vi . "vsm3c.vi vs2, zimm5, vd")
      (vsm3me.vv . "vsm3me.vv vs2, vs1, vd")
    )))

(define rv_zvksh-operand-types
  (make-immutable-hash
    '(
      (vsm3c.vi . (vec imm vec))
      (vsm3me.vv . (vec vec vec))
    )))

(define rv_zvksh-width 32)

;; ====== Helper functions ======

(define (rv_zvksh-get-param-count mnemonic)
  (hash-ref rv_zvksh-param-count mnemonic #f))

(define (rv_zvksh-get-operands mnemonic)
  (hash-ref rv_zvksh-operands mnemonic '()))

(define (rv_zvksh-get-asm mnemonic)
  (hash-ref rv_zvksh-asm mnemonic #f))

(define (rv_zvksh-get-operand-types mnemonic)
  (hash-ref rv_zvksh-operand-types mnemonic '()))

(define (rv_zvksh-get-width) rv_zvksh-width)

(define (rv_zvksh-exists? mnemonic)
  (hash-has-key? rv_zvksh-param-count mnemonic))

(define (rv_zvksh-get-field-position mnemonic field)
  (case field
    [(vs2) (hash-ref rv_zvksh-vs2 mnemonic #f)]
    [(zimm5) (hash-ref rv_zvksh-zimm5 mnemonic #f)]
    [(vd) (hash-ref rv_zvksh-vd mnemonic #f)]
    [(vs1) (hash-ref rv_zvksh-vs1 mnemonic #f)]
    [else #f]))

(provide
  rv_zvksh-vs2
  rv_zvksh-zimm5
  rv_zvksh-vd
  rv_zvksh-vs1
  rv_zvksh-fields
  rv_zvksh-param-count
  rv_zvksh-operands
  rv_zvksh-asm
  rv_zvksh-operand-types
  rv_zvksh-width
  rv_zvksh-get-param-count
  rv_zvksh-get-operands
  rv_zvksh-get-asm
  rv_zvksh-get-operand-types
  rv_zvksh-get-width
  rv_zvksh-exists?
  rv_zvksh-get-field-position)
