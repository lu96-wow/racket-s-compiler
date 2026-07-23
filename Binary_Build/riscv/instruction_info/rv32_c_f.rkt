#lang racket

(define rv32_c_f-rd_p
  (make-immutable-hash
    '(
      (c.flw . 1)
    )))
(define rv32_c_f-rs1_p
  (make-immutable-hash
    '(
      (c.flw . 2)
      (c.fsw . 1)
    )))
(define rv32_c_f-c_uimm7
  (make-immutable-hash
    '(
      (c.flw . 3)
      (c.fsw . 3)
    )))
(define rv32_c_f-rs2_p
  (make-immutable-hash
    '(
      (c.fsw . 2)
    )))
(define rv32_c_f-rd
  (make-immutable-hash
    '(
      (c.flwsp . 1)
    )))
(define rv32_c_f-c_uimm8sp
  (make-immutable-hash
    '(
      (c.flwsp . 2)
    )))
(define rv32_c_f-c_rs2
  (make-immutable-hash
    '(
      (c.fswsp . 1)
    )))
(define rv32_c_f-c_uimm8sp_s
  (make-immutable-hash
    '(
      (c.fswsp . 2)
    )))

(define rv32_c_f-fields '(rd_p rs1_p c_uimm7 rs2_p rd c_uimm8sp c_rs2 c_uimm8sp_s))

(define rv32_c_f-param-count
  (make-immutable-hash
    '(
      (c.flw . 3)
      (c.fsw . 3)
      (c.flwsp . 2)
      (c.fswsp . 2)
    )))

(define rv32_c_f-operands
  (make-immutable-hash
    '(
      (c.flw . (rd_p rs1_p c_uimm7))
      (c.fsw . (rs1_p rs2_p c_uimm7))
      (c.flwsp . (rd c_uimm8sp))
      (c.fswsp . (c_rs2 c_uimm8sp_s))
    )))

(define rv32_c_f-asm
  (make-immutable-hash
    '(
      (c.flw . "c.flw rd_p, rs1_p, c_uimm7")
      (c.fsw . "c.fsw rs1_p, rs2_p, c_uimm7")
      (c.flwsp . "c.flwsp rd, c_uimm8sp")
      (c.fswsp . "c.fswsp c_rs2, c_uimm8sp_s")
    )))

(define rv32_c_f-operand-types
  (make-immutable-hash
    '(
      (c.flw . (reg reg imm))
      (c.fsw . (reg reg imm))
      (c.flwsp . (reg imm))
      (c.fswsp . (reg imm))
    )))

(define rv32_c_f-width 16)

;; ====== Helper functions ======

(define (rv32_c_f-get-param-count mnemonic)
  (hash-ref rv32_c_f-param-count mnemonic #f))

(define (rv32_c_f-get-operands mnemonic)
  (hash-ref rv32_c_f-operands mnemonic '()))

(define (rv32_c_f-get-asm mnemonic)
  (hash-ref rv32_c_f-asm mnemonic #f))

(define (rv32_c_f-get-operand-types mnemonic)
  (hash-ref rv32_c_f-operand-types mnemonic '()))

(define (rv32_c_f-get-width) rv32_c_f-width)

(define (rv32_c_f-exists? mnemonic)
  (hash-has-key? rv32_c_f-param-count mnemonic))

(define (rv32_c_f-get-field-position mnemonic field)
  (case field
    [(rd_p) (hash-ref rv32_c_f-rd_p mnemonic #f)]
    [(rs1_p) (hash-ref rv32_c_f-rs1_p mnemonic #f)]
    [(c_uimm7) (hash-ref rv32_c_f-c_uimm7 mnemonic #f)]
    [(rs2_p) (hash-ref rv32_c_f-rs2_p mnemonic #f)]
    [(rd) (hash-ref rv32_c_f-rd mnemonic #f)]
    [(c_uimm8sp) (hash-ref rv32_c_f-c_uimm8sp mnemonic #f)]
    [(c_rs2) (hash-ref rv32_c_f-c_rs2 mnemonic #f)]
    [(c_uimm8sp_s) (hash-ref rv32_c_f-c_uimm8sp_s mnemonic #f)]
    [else #f]))

(provide
  rv32_c_f-rd_p
  rv32_c_f-rs1_p
  rv32_c_f-c_uimm7
  rv32_c_f-rs2_p
  rv32_c_f-rd
  rv32_c_f-c_uimm8sp
  rv32_c_f-c_rs2
  rv32_c_f-c_uimm8sp_s
  rv32_c_f-fields
  rv32_c_f-param-count
  rv32_c_f-operands
  rv32_c_f-asm
  rv32_c_f-operand-types
  rv32_c_f-width
  rv32_c_f-get-param-count
  rv32_c_f-get-operands
  rv32_c_f-get-asm
  rv32_c_f-get-operand-types
  rv32_c_f-get-width
  rv32_c_f-exists?
  rv32_c_f-get-field-position)
