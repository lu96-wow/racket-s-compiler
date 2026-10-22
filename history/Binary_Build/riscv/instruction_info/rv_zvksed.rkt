#lang racket

(define rv_zvksed-vs2
  (make-immutable-hash
    '(
      (vsm4k.vi . 1)
      (vsm4r.vv . 1)
      (vsm4r.vs . 1)
    )))
(define rv_zvksed-zimm5
  (make-immutable-hash
    '(
      (vsm4k.vi . 2)
    )))
(define rv_zvksed-vd
  (make-immutable-hash
    '(
      (vsm4k.vi . 3)
      (vsm4r.vv . 2)
      (vsm4r.vs . 2)
    )))

(define rv_zvksed-fields '(vs2 zimm5 vd))

(define rv_zvksed-param-count
  (make-immutable-hash
    '(
      (vsm4k.vi . 3)
      (vsm4r.vv . 2)
      (vsm4r.vs . 2)
    )))

(define rv_zvksed-operands
  (make-immutable-hash
    '(
      (vsm4k.vi . (vs2 zimm5 vd))
      (vsm4r.vv . (vs2 vd))
      (vsm4r.vs . (vs2 vd))
    )))

(define rv_zvksed-asm
  (make-immutable-hash
    '(
      (vsm4k.vi . "vsm4k.vi vs2, zimm5, vd")
      (vsm4r.vv . "vsm4r.vv vs2, vd")
      (vsm4r.vs . "vsm4r.vs vs2, vd")
    )))

(define rv_zvksed-operand-types
  (make-immutable-hash
    '(
      (vsm4k.vi . (vec imm vec))
      (vsm4r.vv . (vec vec))
      (vsm4r.vs . (vec vec))
    )))

(define rv_zvksed-width 32)

;; ====== Helper functions ======

(define (rv_zvksed-get-param-count mnemonic)
  (hash-ref rv_zvksed-param-count mnemonic #f))

(define (rv_zvksed-get-operands mnemonic)
  (hash-ref rv_zvksed-operands mnemonic '()))

(define (rv_zvksed-get-asm mnemonic)
  (hash-ref rv_zvksed-asm mnemonic #f))

(define (rv_zvksed-get-operand-types mnemonic)
  (hash-ref rv_zvksed-operand-types mnemonic '()))

(define (rv_zvksed-get-width) rv_zvksed-width)

(define (rv_zvksed-exists? mnemonic)
  (hash-has-key? rv_zvksed-param-count mnemonic))

(define (rv_zvksed-get-field-position mnemonic field)
  (case field
    [(vs2) (hash-ref rv_zvksed-vs2 mnemonic #f)]
    [(zimm5) (hash-ref rv_zvksed-zimm5 mnemonic #f)]
    [(vd) (hash-ref rv_zvksed-vd mnemonic #f)]
    [else #f]))

(provide
  rv_zvksed-vs2
  rv_zvksed-zimm5
  rv_zvksed-vd
  rv_zvksed-fields
  rv_zvksed-param-count
  rv_zvksed-operands
  rv_zvksed-asm
  rv_zvksed-operand-types
  rv_zvksed-width
  rv_zvksed-get-param-count
  rv_zvksed-get-operands
  rv_zvksed-get-asm
  rv_zvksed-get-operand-types
  rv_zvksed-get-width
  rv_zvksed-exists?
  rv_zvksed-get-field-position)
