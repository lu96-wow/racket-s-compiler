#lang racket

(define rv_zvfbfwma-vm
  (make-immutable-hash
    '(
      (vfwmaccbf16.vv . 1)
      (vfwmaccbf16.vf . 1)
    )))
(define rv_zvfbfwma-vs2
  (make-immutable-hash
    '(
      (vfwmaccbf16.vv . 2)
      (vfwmaccbf16.vf . 2)
    )))
(define rv_zvfbfwma-vs1
  (make-immutable-hash
    '(
      (vfwmaccbf16.vv . 3)
    )))
(define rv_zvfbfwma-vd
  (make-immutable-hash
    '(
      (vfwmaccbf16.vv . 4)
      (vfwmaccbf16.vf . 4)
    )))
(define rv_zvfbfwma-rs1
  (make-immutable-hash
    '(
      (vfwmaccbf16.vf . 3)
    )))

(define rv_zvfbfwma-fields '(vm vs2 vs1 vd rs1))

(define rv_zvfbfwma-param-count
  (make-immutable-hash
    '(
      (vfwmaccbf16.vv . 4)
      (vfwmaccbf16.vf . 4)
    )))

(define rv_zvfbfwma-operands
  (make-immutable-hash
    '(
      (vfwmaccbf16.vv . (vm vs2 vs1 vd))
      (vfwmaccbf16.vf . (vm vs2 rs1 vd))
    )))

(define rv_zvfbfwma-asm
  (make-immutable-hash
    '(
      (vfwmaccbf16.vv . "vfwmaccbf16.vv vm, vs2, vs1, vd")
      (vfwmaccbf16.vf . "vfwmaccbf16.vf vm, vs2, rs1, vd")
    )))

(define rv_zvfbfwma-operand-types
  (make-immutable-hash
    '(
      (vfwmaccbf16.vv . (vec vec vec vec))
      (vfwmaccbf16.vf . (vec vec reg vec))
    )))

(define rv_zvfbfwma-width 32)

;; ====== Helper functions ======

(define (rv_zvfbfwma-get-param-count mnemonic)
  (hash-ref rv_zvfbfwma-param-count mnemonic #f))

(define (rv_zvfbfwma-get-operands mnemonic)
  (hash-ref rv_zvfbfwma-operands mnemonic '()))

(define (rv_zvfbfwma-get-asm mnemonic)
  (hash-ref rv_zvfbfwma-asm mnemonic #f))

(define (rv_zvfbfwma-get-operand-types mnemonic)
  (hash-ref rv_zvfbfwma-operand-types mnemonic '()))

(define (rv_zvfbfwma-get-width) rv_zvfbfwma-width)

(define (rv_zvfbfwma-exists? mnemonic)
  (hash-has-key? rv_zvfbfwma-param-count mnemonic))

(define (rv_zvfbfwma-get-field-position mnemonic field)
  (case field
    [(vm) (hash-ref rv_zvfbfwma-vm mnemonic #f)]
    [(vs2) (hash-ref rv_zvfbfwma-vs2 mnemonic #f)]
    [(vs1) (hash-ref rv_zvfbfwma-vs1 mnemonic #f)]
    [(vd) (hash-ref rv_zvfbfwma-vd mnemonic #f)]
    [(rs1) (hash-ref rv_zvfbfwma-rs1 mnemonic #f)]
    [else #f]))

(provide
  rv_zvfbfwma-vm
  rv_zvfbfwma-vs2
  rv_zvfbfwma-vs1
  rv_zvfbfwma-vd
  rv_zvfbfwma-rs1
  rv_zvfbfwma-fields
  rv_zvfbfwma-param-count
  rv_zvfbfwma-operands
  rv_zvfbfwma-asm
  rv_zvfbfwma-operand-types
  rv_zvfbfwma-width
  rv_zvfbfwma-get-param-count
  rv_zvfbfwma-get-operands
  rv_zvfbfwma-get-asm
  rv_zvfbfwma-get-operand-types
  rv_zvfbfwma-get-width
  rv_zvfbfwma-exists?
  rv_zvfbfwma-get-field-position)
