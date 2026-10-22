#lang racket

(define rv_zvknha-vs2
  (make-immutable-hash
    '(
      (vsha2ms.vv . 1)
      (vsha2ch.vv . 1)
      (vsha2cl.vv . 1)
    )))
(define rv_zvknha-vs1
  (make-immutable-hash
    '(
      (vsha2ms.vv . 2)
      (vsha2ch.vv . 2)
      (vsha2cl.vv . 2)
    )))
(define rv_zvknha-vd
  (make-immutable-hash
    '(
      (vsha2ms.vv . 3)
      (vsha2ch.vv . 3)
      (vsha2cl.vv . 3)
    )))

(define rv_zvknha-fields '(vs2 vs1 vd))

(define rv_zvknha-param-count
  (make-immutable-hash
    '(
      (vsha2ms.vv . 3)
      (vsha2ch.vv . 3)
      (vsha2cl.vv . 3)
    )))

(define rv_zvknha-operands
  (make-immutable-hash
    '(
      (vsha2ms.vv . (vs2 vs1 vd))
      (vsha2ch.vv . (vs2 vs1 vd))
      (vsha2cl.vv . (vs2 vs1 vd))
    )))

(define rv_zvknha-asm
  (make-immutable-hash
    '(
      (vsha2ms.vv . "vsha2ms.vv vs2, vs1, vd")
      (vsha2ch.vv . "vsha2ch.vv vs2, vs1, vd")
      (vsha2cl.vv . "vsha2cl.vv vs2, vs1, vd")
    )))

(define rv_zvknha-operand-types
  (make-immutable-hash
    '(
      (vsha2ms.vv . (vec vec vec))
      (vsha2ch.vv . (vec vec vec))
      (vsha2cl.vv . (vec vec vec))
    )))

(define rv_zvknha-width 32)

;; ====== Helper functions ======

(define (rv_zvknha-get-param-count mnemonic)
  (hash-ref rv_zvknha-param-count mnemonic #f))

(define (rv_zvknha-get-operands mnemonic)
  (hash-ref rv_zvknha-operands mnemonic '()))

(define (rv_zvknha-get-asm mnemonic)
  (hash-ref rv_zvknha-asm mnemonic #f))

(define (rv_zvknha-get-operand-types mnemonic)
  (hash-ref rv_zvknha-operand-types mnemonic '()))

(define (rv_zvknha-get-width) rv_zvknha-width)

(define (rv_zvknha-exists? mnemonic)
  (hash-has-key? rv_zvknha-param-count mnemonic))

(define (rv_zvknha-get-field-position mnemonic field)
  (case field
    [(vs2) (hash-ref rv_zvknha-vs2 mnemonic #f)]
    [(vs1) (hash-ref rv_zvknha-vs1 mnemonic #f)]
    [(vd) (hash-ref rv_zvknha-vd mnemonic #f)]
    [else #f]))

(provide
  rv_zvknha-vs2
  rv_zvknha-vs1
  rv_zvknha-vd
  rv_zvknha-fields
  rv_zvknha-param-count
  rv_zvknha-operands
  rv_zvknha-asm
  rv_zvknha-operand-types
  rv_zvknha-width
  rv_zvknha-get-param-count
  rv_zvknha-get-operands
  rv_zvknha-get-asm
  rv_zvknha-get-operand-types
  rv_zvknha-get-width
  rv_zvknha-exists?
  rv_zvknha-get-field-position)
