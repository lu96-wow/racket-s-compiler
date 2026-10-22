#lang racket

(define rv_zvbb-vm
  (make-immutable-hash
    '(
      (vandn.vv . 1)
      (vandn.vx . 1)
      (vbrev.v . 1)
      (vbrev8.v . 1)
      (vrev8.v . 1)
      (vclz.v . 1)
      (vctz.v . 1)
      (vcpop.v . 1)
      (vrol.vv . 1)
      (vrol.vx . 1)
      (vror.vv . 1)
      (vror.vx . 1)
      (vror.vi . 2)
      (vwsll.vv . 1)
      (vwsll.vx . 1)
      (vwsll.vi . 1)
    )))
(define rv_zvbb-vs2
  (make-immutable-hash
    '(
      (vandn.vv . 2)
      (vandn.vx . 2)
      (vbrev.v . 2)
      (vbrev8.v . 2)
      (vrev8.v . 2)
      (vclz.v . 2)
      (vctz.v . 2)
      (vcpop.v . 2)
      (vrol.vv . 2)
      (vrol.vx . 2)
      (vror.vv . 2)
      (vror.vx . 2)
      (vror.vi . 3)
      (vwsll.vv . 2)
      (vwsll.vx . 2)
      (vwsll.vi . 2)
    )))
(define rv_zvbb-vs1
  (make-immutable-hash
    '(
      (vandn.vv . 3)
      (vrol.vv . 3)
      (vror.vv . 3)
      (vwsll.vv . 3)
    )))
(define rv_zvbb-vd
  (make-immutable-hash
    '(
      (vandn.vv . 4)
      (vandn.vx . 4)
      (vbrev.v . 3)
      (vbrev8.v . 3)
      (vrev8.v . 3)
      (vclz.v . 3)
      (vctz.v . 3)
      (vcpop.v . 3)
      (vrol.vv . 4)
      (vrol.vx . 4)
      (vror.vv . 4)
      (vror.vx . 4)
      (vror.vi . 4)
      (vwsll.vv . 4)
      (vwsll.vx . 4)
      (vwsll.vi . 4)
    )))
(define rv_zvbb-rs1
  (make-immutable-hash
    '(
      (vandn.vx . 3)
      (vrol.vx . 3)
      (vror.vx . 3)
      (vwsll.vx . 3)
    )))
(define rv_zvbb-zimm6
  (make-immutable-hash
    '(
      (vror.vi . 1)
    )))
(define rv_zvbb-zimm5
  (make-immutable-hash
    '(
      (vwsll.vi . 3)
    )))

(define rv_zvbb-fields '(vm vs2 vs1 vd rs1 zimm6 zimm5))

(define rv_zvbb-param-count
  (make-immutable-hash
    '(
      (vandn.vv . 4)
      (vandn.vx . 4)
      (vbrev.v . 3)
      (vbrev8.v . 3)
      (vrev8.v . 3)
      (vclz.v . 3)
      (vctz.v . 3)
      (vcpop.v . 3)
      (vrol.vv . 4)
      (vrol.vx . 4)
      (vror.vv . 4)
      (vror.vx . 4)
      (vror.vi . 4)
      (vwsll.vv . 4)
      (vwsll.vx . 4)
      (vwsll.vi . 4)
    )))

(define rv_zvbb-operands
  (make-immutable-hash
    '(
      (vandn.vv . (vm vs2 vs1 vd))
      (vandn.vx . (vm vs2 rs1 vd))
      (vbrev.v . (vm vs2 vd))
      (vbrev8.v . (vm vs2 vd))
      (vrev8.v . (vm vs2 vd))
      (vclz.v . (vm vs2 vd))
      (vctz.v . (vm vs2 vd))
      (vcpop.v . (vm vs2 vd))
      (vrol.vv . (vm vs2 vs1 vd))
      (vrol.vx . (vm vs2 rs1 vd))
      (vror.vv . (vm vs2 vs1 vd))
      (vror.vx . (vm vs2 rs1 vd))
      (vror.vi . (zimm6 vm vs2 vd))
      (vwsll.vv . (vm vs2 vs1 vd))
      (vwsll.vx . (vm vs2 rs1 vd))
      (vwsll.vi . (vm vs2 zimm5 vd))
    )))

(define rv_zvbb-asm
  (make-immutable-hash
    '(
      (vandn.vv . "vandn.vv vm, vs2, vs1, vd")
      (vandn.vx . "vandn.vx vm, vs2, rs1, vd")
      (vbrev.v . "vbrev.v vm, vs2, vd")
      (vbrev8.v . "vbrev8.v vm, vs2, vd")
      (vrev8.v . "vrev8.v vm, vs2, vd")
      (vclz.v . "vclz.v vm, vs2, vd")
      (vctz.v . "vctz.v vm, vs2, vd")
      (vcpop.v . "vcpop.v vm, vs2, vd")
      (vrol.vv . "vrol.vv vm, vs2, vs1, vd")
      (vrol.vx . "vrol.vx vm, vs2, rs1, vd")
      (vror.vv . "vror.vv vm, vs2, vs1, vd")
      (vror.vx . "vror.vx vm, vs2, rs1, vd")
      (vror.vi . "vror.vi zimm6, vm, vs2, vd")
      (vwsll.vv . "vwsll.vv vm, vs2, vs1, vd")
      (vwsll.vx . "vwsll.vx vm, vs2, rs1, vd")
      (vwsll.vi . "vwsll.vi vm, vs2, zimm5, vd")
    )))

(define rv_zvbb-operand-types
  (make-immutable-hash
    '(
      (vandn.vv . (vec vec vec vec))
      (vandn.vx . (vec vec reg vec))
      (vbrev.v . (vec vec vec))
      (vbrev8.v . (vec vec vec))
      (vrev8.v . (vec vec vec))
      (vclz.v . (vec vec vec))
      (vctz.v . (vec vec vec))
      (vcpop.v . (vec vec vec))
      (vrol.vv . (vec vec vec vec))
      (vrol.vx . (vec vec reg vec))
      (vror.vv . (vec vec vec vec))
      (vror.vx . (vec vec reg vec))
      (vror.vi . (imm vec vec vec))
      (vwsll.vv . (vec vec vec vec))
      (vwsll.vx . (vec vec reg vec))
      (vwsll.vi . (vec vec imm vec))
    )))

(define rv_zvbb-width 32)

;; ====== Helper functions ======

(define (rv_zvbb-get-param-count mnemonic)
  (hash-ref rv_zvbb-param-count mnemonic #f))

(define (rv_zvbb-get-operands mnemonic)
  (hash-ref rv_zvbb-operands mnemonic '()))

(define (rv_zvbb-get-asm mnemonic)
  (hash-ref rv_zvbb-asm mnemonic #f))

(define (rv_zvbb-get-operand-types mnemonic)
  (hash-ref rv_zvbb-operand-types mnemonic '()))

(define (rv_zvbb-get-width) rv_zvbb-width)

(define (rv_zvbb-exists? mnemonic)
  (hash-has-key? rv_zvbb-param-count mnemonic))

(define (rv_zvbb-get-field-position mnemonic field)
  (case field
    [(vm) (hash-ref rv_zvbb-vm mnemonic #f)]
    [(vs2) (hash-ref rv_zvbb-vs2 mnemonic #f)]
    [(vs1) (hash-ref rv_zvbb-vs1 mnemonic #f)]
    [(vd) (hash-ref rv_zvbb-vd mnemonic #f)]
    [(rs1) (hash-ref rv_zvbb-rs1 mnemonic #f)]
    [(zimm6) (hash-ref rv_zvbb-zimm6 mnemonic #f)]
    [(zimm5) (hash-ref rv_zvbb-zimm5 mnemonic #f)]
    [else #f]))

(provide
  rv_zvbb-vm
  rv_zvbb-vs2
  rv_zvbb-vs1
  rv_zvbb-vd
  rv_zvbb-rs1
  rv_zvbb-zimm6
  rv_zvbb-zimm5
  rv_zvbb-fields
  rv_zvbb-param-count
  rv_zvbb-operands
  rv_zvbb-asm
  rv_zvbb-operand-types
  rv_zvbb-width
  rv_zvbb-get-param-count
  rv_zvbb-get-operands
  rv_zvbb-get-asm
  rv_zvbb-get-operand-types
  rv_zvbb-get-width
  rv_zvbb-exists?
  rv_zvbb-get-field-position)
