#lang racket

(define rv_c-rd_p
  (make-immutable-hash
    '(
      (c.addi4spn . 1)
      (c.lw . 1)
    )))
(define rv_c-c_nzuimm10
  (make-immutable-hash
    '(
      (c.addi4spn . 2)
    )))
(define rv_c-rs1_p
  (make-immutable-hash
    '(
      (c.lw . 2)
      (c.sw . 1)
      (c.beqz . 1)
      (c.bnez . 1)
    )))
(define rv_c-c_uimm7
  (make-immutable-hash
    '(
      (c.lw . 3)
      (c.sw . 3)
    )))
(define rv_c-rs2_p
  (make-immutable-hash
    '(
      (c.sw . 2)
      (c.sub . 2)
      (c.xor . 2)
      (c.or . 2)
      (c.and . 2)
    )))
(define rv_c-c_nzimm6
  (make-immutable-hash
    '(
      (c.nop . 1)
      (c.addi . 2)
    )))
(define rv_c-rd_rs1_n0
  (make-immutable-hash
    '(
      (c.addi . 1)
      (c.add . 1)
    )))
(define rv_c-rd_n0
  (make-immutable-hash
    '(
      (c.li . 1)
      (c.lwsp . 1)
      (c.mv . 1)
    )))
(define rv_c-c_imm6
  (make-immutable-hash
    '(
      (c.li . 2)
      (c.andi . 2)
    )))
(define rv_c-c_nzimm10
  (make-immutable-hash
    '(
      (c.addi16sp . 1)
    )))
(define rv_c-rd_n2
  (make-immutable-hash
    '(
      (c.lui . 1)
    )))
(define rv_c-c_nzimm18
  (make-immutable-hash
    '(
      (c.lui . 2)
    )))
(define rv_c-rd_rs1_p
  (make-immutable-hash
    '(
      (c.andi . 1)
      (c.sub . 1)
      (c.xor . 1)
      (c.or . 1)
      (c.and . 1)
    )))
(define rv_c-c_imm12
  (make-immutable-hash
    '(
      (c.j . 1)
    )))
(define rv_c-c_bimm9
  (make-immutable-hash
    '(
      (c.beqz . 2)
      (c.bnez . 2)
    )))
(define rv_c-c_uimm8sp
  (make-immutable-hash
    '(
      (c.lwsp . 2)
    )))
(define rv_c-rs1_n0
  (make-immutable-hash
    '(
      (c.jr . 1)
    )))
(define rv_c-c_rs2_n0
  (make-immutable-hash
    '(
      (c.mv . 2)
      (c.add . 2)
    )))
(define rv_c-c_rs1_n0
  (make-immutable-hash
    '(
      (c.jalr . 1)
    )))
(define rv_c-c_rs2
  (make-immutable-hash
    '(
      (c.swsp . 1)
    )))
(define rv_c-c_uimm8sp_s
  (make-immutable-hash
    '(
      (c.swsp . 2)
    )))

(define rv_c-fields '(rd_p c_nzuimm10 rs1_p c_uimm7 rs2_p c_nzimm6 rd_rs1_n0 rd_n0 c_imm6 c_nzimm10 rd_n2 c_nzimm18 rd_rs1_p c_imm12 c_bimm9 c_uimm8sp rs1_n0 c_rs2_n0 c_rs1_n0 c_rs2 c_uimm8sp_s))

(define rv_c-param-count
  (make-immutable-hash
    '(
      (c.addi4spn . 2)
      (c.lw . 3)
      (c.sw . 3)
      (c.nop . 1)
      (c.addi . 2)
      (c.li . 2)
      (c.addi16sp . 1)
      (c.lui . 2)
      (c.andi . 2)
      (c.sub . 2)
      (c.xor . 2)
      (c.or . 2)
      (c.and . 2)
      (c.j . 1)
      (c.beqz . 2)
      (c.bnez . 2)
      (c.lwsp . 2)
      (c.jr . 1)
      (c.mv . 2)
      (c.ebreak . 0)
      (c.jalr . 1)
      (c.add . 2)
      (c.swsp . 2)
    )))

(define rv_c-operands
  (make-immutable-hash
    '(
      (c.addi4spn . (rd_p c_nzuimm10))
      (c.lw . (rd_p rs1_p c_uimm7))
      (c.sw . (rs1_p rs2_p c_uimm7))
      (c.nop . (c_nzimm6))
      (c.addi . (rd_rs1_n0 c_nzimm6))
      (c.li . (rd_n0 c_imm6))
      (c.addi16sp . (c_nzimm10))
      (c.lui . (rd_n2 c_nzimm18))
      (c.andi . (rd_rs1_p c_imm6))
      (c.sub . (rd_rs1_p rs2_p))
      (c.xor . (rd_rs1_p rs2_p))
      (c.or . (rd_rs1_p rs2_p))
      (c.and . (rd_rs1_p rs2_p))
      (c.j . (c_imm12))
      (c.beqz . (rs1_p c_bimm9))
      (c.bnez . (rs1_p c_bimm9))
      (c.lwsp . (rd_n0 c_uimm8sp))
      (c.jr . (rs1_n0))
      (c.mv . (rd_n0 c_rs2_n0))
      (c.ebreak . ())
      (c.jalr . (c_rs1_n0))
      (c.add . (rd_rs1_n0 c_rs2_n0))
      (c.swsp . (c_rs2 c_uimm8sp_s))
    )))

(define rv_c-asm
  (make-immutable-hash
    '(
      (c.addi4spn . "c.addi4spn rd_p, c_nzuimm10")
      (c.lw . "c.lw rd_p, rs1_p, c_uimm7")
      (c.sw . "c.sw rs1_p, rs2_p, c_uimm7")
      (c.nop . "c.nop c_nzimm6")
      (c.addi . "c.addi rd_rs1_n0, c_nzimm6")
      (c.li . "c.li rd_n0, c_imm6")
      (c.addi16sp . "c.addi16sp c_nzimm10")
      (c.lui . "c.lui rd_n2, c_nzimm18")
      (c.andi . "c.andi rd_rs1_p, c_imm6")
      (c.sub . "c.sub rd_rs1_p, rs2_p")
      (c.xor . "c.xor rd_rs1_p, rs2_p")
      (c.or . "c.or rd_rs1_p, rs2_p")
      (c.and . "c.and rd_rs1_p, rs2_p")
      (c.j . "c.j c_imm12")
      (c.beqz . "c.beqz rs1_p, c_bimm9")
      (c.bnez . "c.bnez rs1_p, c_bimm9")
      (c.lwsp . "c.lwsp rd_n0, c_uimm8sp")
      (c.jr . "c.jr rs1_n0")
      (c.mv . "c.mv rd_n0, c_rs2_n0")
      (c.ebreak . "c.ebreak")
      (c.jalr . "c.jalr c_rs1_n0")
      (c.add . "c.add rd_rs1_n0, c_rs2_n0")
      (c.swsp . "c.swsp c_rs2, c_uimm8sp_s")
    )))

(define rv_c-operand-types
  (make-immutable-hash
    '(
      (c.addi4spn . (reg imm))
      (c.lw . (reg reg imm))
      (c.sw . (reg reg imm))
      (c.nop . (imm))
      (c.addi . (reg imm))
      (c.li . (reg imm))
      (c.addi16sp . (imm))
      (c.lui . (reg imm))
      (c.andi . (reg imm))
      (c.sub . (reg reg))
      (c.xor . (reg reg))
      (c.or . (reg reg))
      (c.and . (reg reg))
      (c.j . (imm))
      (c.beqz . (reg imm))
      (c.bnez . (reg imm))
      (c.lwsp . (reg imm))
      (c.jr . (reg))
      (c.mv . (reg reg))
      (c.ebreak . ())
      (c.jalr . (reg))
      (c.add . (reg reg))
      (c.swsp . (reg imm))
    )))

(define rv_c-width 16)

;; ====== Helper functions ======

(define (rv_c-get-param-count mnemonic)
  (hash-ref rv_c-param-count mnemonic #f))

(define (rv_c-get-operands mnemonic)
  (hash-ref rv_c-operands mnemonic '()))

(define (rv_c-get-asm mnemonic)
  (hash-ref rv_c-asm mnemonic #f))

(define (rv_c-get-operand-types mnemonic)
  (hash-ref rv_c-operand-types mnemonic '()))

(define (rv_c-get-width) rv_c-width)

(define (rv_c-exists? mnemonic)
  (hash-has-key? rv_c-param-count mnemonic))

(define (rv_c-get-field-position mnemonic field)
  (case field
    [(rd_p) (hash-ref rv_c-rd_p mnemonic #f)]
    [(c_nzuimm10) (hash-ref rv_c-c_nzuimm10 mnemonic #f)]
    [(rs1_p) (hash-ref rv_c-rs1_p mnemonic #f)]
    [(c_uimm7) (hash-ref rv_c-c_uimm7 mnemonic #f)]
    [(rs2_p) (hash-ref rv_c-rs2_p mnemonic #f)]
    [(c_nzimm6) (hash-ref rv_c-c_nzimm6 mnemonic #f)]
    [(rd_rs1_n0) (hash-ref rv_c-rd_rs1_n0 mnemonic #f)]
    [(rd_n0) (hash-ref rv_c-rd_n0 mnemonic #f)]
    [(c_imm6) (hash-ref rv_c-c_imm6 mnemonic #f)]
    [(c_nzimm10) (hash-ref rv_c-c_nzimm10 mnemonic #f)]
    [(rd_n2) (hash-ref rv_c-rd_n2 mnemonic #f)]
    [(c_nzimm18) (hash-ref rv_c-c_nzimm18 mnemonic #f)]
    [(rd_rs1_p) (hash-ref rv_c-rd_rs1_p mnemonic #f)]
    [(c_imm12) (hash-ref rv_c-c_imm12 mnemonic #f)]
    [(c_bimm9) (hash-ref rv_c-c_bimm9 mnemonic #f)]
    [(c_uimm8sp) (hash-ref rv_c-c_uimm8sp mnemonic #f)]
    [(rs1_n0) (hash-ref rv_c-rs1_n0 mnemonic #f)]
    [(c_rs2_n0) (hash-ref rv_c-c_rs2_n0 mnemonic #f)]
    [(c_rs1_n0) (hash-ref rv_c-c_rs1_n0 mnemonic #f)]
    [(c_rs2) (hash-ref rv_c-c_rs2 mnemonic #f)]
    [(c_uimm8sp_s) (hash-ref rv_c-c_uimm8sp_s mnemonic #f)]
    [else #f]))

(provide
  rv_c-rd_p
  rv_c-c_nzuimm10
  rv_c-rs1_p
  rv_c-c_uimm7
  rv_c-rs2_p
  rv_c-c_nzimm6
  rv_c-rd_rs1_n0
  rv_c-rd_n0
  rv_c-c_imm6
  rv_c-c_nzimm10
  rv_c-rd_n2
  rv_c-c_nzimm18
  rv_c-rd_rs1_p
  rv_c-c_imm12
  rv_c-c_bimm9
  rv_c-c_uimm8sp
  rv_c-rs1_n0
  rv_c-c_rs2_n0
  rv_c-c_rs1_n0
  rv_c-c_rs2
  rv_c-c_uimm8sp_s
  rv_c-fields
  rv_c-param-count
  rv_c-operands
  rv_c-asm
  rv_c-operand-types
  rv_c-width
  rv_c-get-param-count
  rv_c-get-operands
  rv_c-get-asm
  rv_c-get-operand-types
  rv_c-get-width
  rv_c-exists?
  rv_c-get-field-position)
