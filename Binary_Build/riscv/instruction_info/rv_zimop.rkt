#lang racket

(define rv_zimop-mop_r_t_30
  (make-immutable-hash
    '(
      (mop.r.N . 1)
    )))
(define rv_zimop-mop_r_t_27_26
  (make-immutable-hash
    '(
      (mop.r.N . 2)
    )))
(define rv_zimop-mop_r_t_21_20
  (make-immutable-hash
    '(
      (mop.r.N . 3)
    )))
(define rv_zimop-rd
  (make-immutable-hash
    '(
      (mop.r.N . 4)
      (mop.rr.N . 3)
    )))
(define rv_zimop-rs1
  (make-immutable-hash
    '(
      (mop.r.N . 5)
      (mop.rr.N . 4)
    )))
(define rv_zimop-mop_rr_t_30
  (make-immutable-hash
    '(
      (mop.rr.N . 1)
    )))
(define rv_zimop-mop_rr_t_27_26
  (make-immutable-hash
    '(
      (mop.rr.N . 2)
    )))
(define rv_zimop-rs2
  (make-immutable-hash
    '(
      (mop.rr.N . 5)
    )))

(define rv_zimop-fields '(mop_r_t_30 mop_r_t_27_26 mop_r_t_21_20 rd rs1 mop_rr_t_30 mop_rr_t_27_26 rs2))

(define rv_zimop-param-count
  (make-immutable-hash
    '(
      (mop.r.N . 5)
      (mop.rr.N . 5)
    )))

(define rv_zimop-operands
  (make-immutable-hash
    '(
      (mop.r.N . (mop_r_t_30 mop_r_t_27_26 mop_r_t_21_20 rd rs1))
      (mop.rr.N . (mop_rr_t_30 mop_rr_t_27_26 rd rs1 rs2))
    )))

(define rv_zimop-asm
  (make-immutable-hash
    '(
      (mop.r.N . "mop.r.N mop_r_t_30, mop_r_t_27_26, mop_r_t_21_20, rd, rs1")
      (mop.rr.N . "mop.rr.N mop_rr_t_30, mop_rr_t_27_26, rd, rs1, rs2")
    )))

(define rv_zimop-operand-types
  (make-immutable-hash
    '(
      (mop.r.N . (imm imm imm reg reg))
      (mop.rr.N . (imm imm reg reg reg))
    )))

(define rv_zimop-width 32)

;; ====== Helper functions ======

(define (rv_zimop-get-param-count mnemonic)
  (hash-ref rv_zimop-param-count mnemonic #f))

(define (rv_zimop-get-operands mnemonic)
  (hash-ref rv_zimop-operands mnemonic '()))

(define (rv_zimop-get-asm mnemonic)
  (hash-ref rv_zimop-asm mnemonic #f))

(define (rv_zimop-get-operand-types mnemonic)
  (hash-ref rv_zimop-operand-types mnemonic '()))

(define (rv_zimop-get-width) rv_zimop-width)

(define (rv_zimop-exists? mnemonic)
  (hash-has-key? rv_zimop-param-count mnemonic))

(define (rv_zimop-get-field-position mnemonic field)
  (case field
    [(mop_r_t_30) (hash-ref rv_zimop-mop_r_t_30 mnemonic #f)]
    [(mop_r_t_27_26) (hash-ref rv_zimop-mop_r_t_27_26 mnemonic #f)]
    [(mop_r_t_21_20) (hash-ref rv_zimop-mop_r_t_21_20 mnemonic #f)]
    [(rd) (hash-ref rv_zimop-rd mnemonic #f)]
    [(rs1) (hash-ref rv_zimop-rs1 mnemonic #f)]
    [(mop_rr_t_30) (hash-ref rv_zimop-mop_rr_t_30 mnemonic #f)]
    [(mop_rr_t_27_26) (hash-ref rv_zimop-mop_rr_t_27_26 mnemonic #f)]
    [(rs2) (hash-ref rv_zimop-rs2 mnemonic #f)]
    [else #f]))

(provide
  rv_zimop-mop_r_t_30
  rv_zimop-mop_r_t_27_26
  rv_zimop-mop_r_t_21_20
  rv_zimop-rd
  rv_zimop-rs1
  rv_zimop-mop_rr_t_30
  rv_zimop-mop_rr_t_27_26
  rv_zimop-rs2
  rv_zimop-fields
  rv_zimop-param-count
  rv_zimop-operands
  rv_zimop-asm
  rv_zimop-operand-types
  rv_zimop-width
  rv_zimop-get-param-count
  rv_zimop-get-operands
  rv_zimop-get-asm
  rv_zimop-get-operand-types
  rv_zimop-get-width
  rv_zimop-exists?
  rv_zimop-get-field-position)
