#lang racket

(define rv_zcmp-c_rlist
  (make-immutable-hash
    '(
      (cm.push . 1)
      (cm.pop . 1)
      (cm.popretz . 1)
      (cm.popret . 1)
    )))
(define rv_zcmp-c_spimm
  (make-immutable-hash
    '(
      (cm.push . 2)
      (cm.pop . 2)
      (cm.popretz . 2)
      (cm.popret . 2)
    )))
(define rv_zcmp-c_sreg1
  (make-immutable-hash
    '(
      (cm.mvsa01 . 1)
      (cm.mva01s . 1)
    )))
(define rv_zcmp-c_sreg2
  (make-immutable-hash
    '(
      (cm.mvsa01 . 2)
      (cm.mva01s . 2)
    )))

(define rv_zcmp-fields '(c_rlist c_spimm c_sreg1 c_sreg2))

(define rv_zcmp-param-count
  (make-immutable-hash
    '(
      (cm.push . 2)
      (cm.pop . 2)
      (cm.popretz . 2)
      (cm.popret . 2)
      (cm.mvsa01 . 2)
      (cm.mva01s . 2)
    )))

(define rv_zcmp-operands
  (make-immutable-hash
    '(
      (cm.push . (c_rlist c_spimm))
      (cm.pop . (c_rlist c_spimm))
      (cm.popretz . (c_rlist c_spimm))
      (cm.popret . (c_rlist c_spimm))
      (cm.mvsa01 . (c_sreg1 c_sreg2))
      (cm.mva01s . (c_sreg1 c_sreg2))
    )))

(define rv_zcmp-asm
  (make-immutable-hash
    '(
      (cm.push . "cm.push c_rlist, c_spimm")
      (cm.pop . "cm.pop c_rlist, c_spimm")
      (cm.popretz . "cm.popretz c_rlist, c_spimm")
      (cm.popret . "cm.popret c_rlist, c_spimm")
      (cm.mvsa01 . "cm.mvsa01 c_sreg1, c_sreg2")
      (cm.mva01s . "cm.mva01s c_sreg1, c_sreg2")
    )))

(define rv_zcmp-operand-types
  (make-immutable-hash
    '(
      (cm.push . (vec imm))
      (cm.pop . (vec imm))
      (cm.popretz . (vec imm))
      (cm.popret . (vec imm))
      (cm.mvsa01 . (reg reg))
      (cm.mva01s . (reg reg))
    )))

(define rv_zcmp-width 16)

;; ====== Helper functions ======

(define (rv_zcmp-get-param-count mnemonic)
  (hash-ref rv_zcmp-param-count mnemonic #f))

(define (rv_zcmp-get-operands mnemonic)
  (hash-ref rv_zcmp-operands mnemonic '()))

(define (rv_zcmp-get-asm mnemonic)
  (hash-ref rv_zcmp-asm mnemonic #f))

(define (rv_zcmp-get-operand-types mnemonic)
  (hash-ref rv_zcmp-operand-types mnemonic '()))

(define (rv_zcmp-get-width) rv_zcmp-width)

(define (rv_zcmp-exists? mnemonic)
  (hash-has-key? rv_zcmp-param-count mnemonic))

(define (rv_zcmp-get-field-position mnemonic field)
  (case field
    [(c_rlist) (hash-ref rv_zcmp-c_rlist mnemonic #f)]
    [(c_spimm) (hash-ref rv_zcmp-c_spimm mnemonic #f)]
    [(c_sreg1) (hash-ref rv_zcmp-c_sreg1 mnemonic #f)]
    [(c_sreg2) (hash-ref rv_zcmp-c_sreg2 mnemonic #f)]
    [else #f]))

(provide
  rv_zcmp-c_rlist
  rv_zcmp-c_spimm
  rv_zcmp-c_sreg1
  rv_zcmp-c_sreg2
  rv_zcmp-fields
  rv_zcmp-param-count
  rv_zcmp-operands
  rv_zcmp-asm
  rv_zcmp-operand-types
  rv_zcmp-width
  rv_zcmp-get-param-count
  rv_zcmp-get-operands
  rv_zcmp-get-asm
  rv_zcmp-get-operand-types
  rv_zcmp-get-width
  rv_zcmp-exists?
  rv_zcmp-get-field-position)
