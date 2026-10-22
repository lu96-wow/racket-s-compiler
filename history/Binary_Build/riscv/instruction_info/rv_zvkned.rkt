#lang racket

(define rv_zvkned-vs2
  (make-immutable-hash
    '(
      (vaesdf.vv . 1)
      (vaesdf.vs . 1)
      (vaesdm.vv . 1)
      (vaesdm.vs . 1)
      (vaesef.vv . 1)
      (vaesef.vs . 1)
      (vaesem.vv . 1)
      (vaesem.vs . 1)
      (vaesz.vs . 1)
      (vaeskf1.vi . 1)
      (vaeskf2.vi . 1)
    )))
(define rv_zvkned-vd
  (make-immutable-hash
    '(
      (vaesdf.vv . 2)
      (vaesdf.vs . 2)
      (vaesdm.vv . 2)
      (vaesdm.vs . 2)
      (vaesef.vv . 2)
      (vaesef.vs . 2)
      (vaesem.vv . 2)
      (vaesem.vs . 2)
      (vaesz.vs . 2)
      (vaeskf1.vi . 3)
      (vaeskf2.vi . 3)
    )))
(define rv_zvkned-zimm5
  (make-immutable-hash
    '(
      (vaeskf1.vi . 2)
      (vaeskf2.vi . 2)
    )))

(define rv_zvkned-fields '(vs2 vd zimm5))

(define rv_zvkned-param-count
  (make-immutable-hash
    '(
      (vaesdf.vv . 2)
      (vaesdf.vs . 2)
      (vaesdm.vv . 2)
      (vaesdm.vs . 2)
      (vaesef.vv . 2)
      (vaesef.vs . 2)
      (vaesem.vv . 2)
      (vaesem.vs . 2)
      (vaesz.vs . 2)
      (vaeskf1.vi . 3)
      (vaeskf2.vi . 3)
    )))

(define rv_zvkned-operands
  (make-immutable-hash
    '(
      (vaesdf.vv . (vs2 vd))
      (vaesdf.vs . (vs2 vd))
      (vaesdm.vv . (vs2 vd))
      (vaesdm.vs . (vs2 vd))
      (vaesef.vv . (vs2 vd))
      (vaesef.vs . (vs2 vd))
      (vaesem.vv . (vs2 vd))
      (vaesem.vs . (vs2 vd))
      (vaesz.vs . (vs2 vd))
      (vaeskf1.vi . (vs2 zimm5 vd))
      (vaeskf2.vi . (vs2 zimm5 vd))
    )))

(define rv_zvkned-asm
  (make-immutable-hash
    '(
      (vaesdf.vv . "vaesdf.vv vs2, vd")
      (vaesdf.vs . "vaesdf.vs vs2, vd")
      (vaesdm.vv . "vaesdm.vv vs2, vd")
      (vaesdm.vs . "vaesdm.vs vs2, vd")
      (vaesef.vv . "vaesef.vv vs2, vd")
      (vaesef.vs . "vaesef.vs vs2, vd")
      (vaesem.vv . "vaesem.vv vs2, vd")
      (vaesem.vs . "vaesem.vs vs2, vd")
      (vaesz.vs . "vaesz.vs vs2, vd")
      (vaeskf1.vi . "vaeskf1.vi vs2, zimm5, vd")
      (vaeskf2.vi . "vaeskf2.vi vs2, zimm5, vd")
    )))

(define rv_zvkned-operand-types
  (make-immutable-hash
    '(
      (vaesdf.vv . (vec vec))
      (vaesdf.vs . (vec vec))
      (vaesdm.vv . (vec vec))
      (vaesdm.vs . (vec vec))
      (vaesef.vv . (vec vec))
      (vaesef.vs . (vec vec))
      (vaesem.vv . (vec vec))
      (vaesem.vs . (vec vec))
      (vaesz.vs . (vec vec))
      (vaeskf1.vi . (vec imm vec))
      (vaeskf2.vi . (vec imm vec))
    )))

(define rv_zvkned-width 32)

;; ====== Helper functions ======

(define (rv_zvkned-get-param-count mnemonic)
  (hash-ref rv_zvkned-param-count mnemonic #f))

(define (rv_zvkned-get-operands mnemonic)
  (hash-ref rv_zvkned-operands mnemonic '()))

(define (rv_zvkned-get-asm mnemonic)
  (hash-ref rv_zvkned-asm mnemonic #f))

(define (rv_zvkned-get-operand-types mnemonic)
  (hash-ref rv_zvkned-operand-types mnemonic '()))

(define (rv_zvkned-get-width) rv_zvkned-width)

(define (rv_zvkned-exists? mnemonic)
  (hash-has-key? rv_zvkned-param-count mnemonic))

(define (rv_zvkned-get-field-position mnemonic field)
  (case field
    [(vs2) (hash-ref rv_zvkned-vs2 mnemonic #f)]
    [(vd) (hash-ref rv_zvkned-vd mnemonic #f)]
    [(zimm5) (hash-ref rv_zvkned-zimm5 mnemonic #f)]
    [else #f]))

(provide
  rv_zvkned-vs2
  rv_zvkned-vd
  rv_zvkned-zimm5
  rv_zvkned-fields
  rv_zvkned-param-count
  rv_zvkned-operands
  rv_zvkned-asm
  rv_zvkned-operand-types
  rv_zvkned-width
  rv_zvkned-get-param-count
  rv_zvkned-get-operands
  rv_zvkned-get-asm
  rv_zvkned-get-operand-types
  rv_zvkned-get-width
  rv_zvkned-exists?
  rv_zvkned-get-field-position)
