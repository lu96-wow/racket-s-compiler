#lang racket

(define rv_zvfbfmin-vm
  (make-immutable-hash
    '(
      (vfncvtbf16.f.f.w . 1)
      (vfwcvtbf16.f.f.v . 1)
    )))
(define rv_zvfbfmin-vs2
  (make-immutable-hash
    '(
      (vfncvtbf16.f.f.w . 2)
      (vfwcvtbf16.f.f.v . 2)
    )))
(define rv_zvfbfmin-vd
  (make-immutable-hash
    '(
      (vfncvtbf16.f.f.w . 3)
      (vfwcvtbf16.f.f.v . 3)
    )))

(define rv_zvfbfmin-fields '(vm vs2 vd))

(define rv_zvfbfmin-param-count
  (make-immutable-hash
    '(
      (vfncvtbf16.f.f.w . 3)
      (vfwcvtbf16.f.f.v . 3)
    )))

(define rv_zvfbfmin-operands
  (make-immutable-hash
    '(
      (vfncvtbf16.f.f.w . (vm vs2 vd))
      (vfwcvtbf16.f.f.v . (vm vs2 vd))
    )))

(define rv_zvfbfmin-asm
  (make-immutable-hash
    '(
      (vfncvtbf16.f.f.w . "vfncvtbf16.f.f.w vm, vs2, vd")
      (vfwcvtbf16.f.f.v . "vfwcvtbf16.f.f.v vm, vs2, vd")
    )))

(define rv_zvfbfmin-operand-types
  (make-immutable-hash
    '(
      (vfncvtbf16.f.f.w . (vec vec vec))
      (vfwcvtbf16.f.f.v . (vec vec vec))
    )))

(define rv_zvfbfmin-width 32)

;; ====== Helper functions ======

(define (rv_zvfbfmin-get-param-count mnemonic)
  (hash-ref rv_zvfbfmin-param-count mnemonic #f))

(define (rv_zvfbfmin-get-operands mnemonic)
  (hash-ref rv_zvfbfmin-operands mnemonic '()))

(define (rv_zvfbfmin-get-asm mnemonic)
  (hash-ref rv_zvfbfmin-asm mnemonic #f))

(define (rv_zvfbfmin-get-operand-types mnemonic)
  (hash-ref rv_zvfbfmin-operand-types mnemonic '()))

(define (rv_zvfbfmin-get-width) rv_zvfbfmin-width)

(define (rv_zvfbfmin-exists? mnemonic)
  (hash-has-key? rv_zvfbfmin-param-count mnemonic))

(define (rv_zvfbfmin-get-field-position mnemonic field)
  (case field
    [(vm) (hash-ref rv_zvfbfmin-vm mnemonic #f)]
    [(vs2) (hash-ref rv_zvfbfmin-vs2 mnemonic #f)]
    [(vd) (hash-ref rv_zvfbfmin-vd mnemonic #f)]
    [else #f]))

(provide
  rv_zvfbfmin-vm
  rv_zvfbfmin-vs2
  rv_zvfbfmin-vd
  rv_zvfbfmin-fields
  rv_zvfbfmin-param-count
  rv_zvfbfmin-operands
  rv_zvfbfmin-asm
  rv_zvfbfmin-operand-types
  rv_zvfbfmin-width
  rv_zvfbfmin-get-param-count
  rv_zvfbfmin-get-operands
  rv_zvfbfmin-get-asm
  rv_zvfbfmin-get-operand-types
  rv_zvfbfmin-get-width
  rv_zvfbfmin-exists?
  rv_zvfbfmin-get-field-position)
