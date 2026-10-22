#lang racket

(define rv64_c-rd_p
  (make-immutable-hash
    '(
      (c.ld . 1)
    )))
(define rv64_c-rs1_p
  (make-immutable-hash
    '(
      (c.ld . 2)
      (c.sd . 1)
    )))
(define rv64_c-c_uimm8
  (make-immutable-hash
    '(
      (c.ld . 3)
      (c.sd . 3)
    )))
(define rv64_c-rs2_p
  (make-immutable-hash
    '(
      (c.sd . 2)
      (c.subw . 2)
      (c.addw . 2)
    )))
(define rv64_c-rd_rs1_n0
  (make-immutable-hash
    '(
      (c.addiw . 1)
      (c.slli . 1)
    )))
(define rv64_c-c_imm6
  (make-immutable-hash
    '(
      (c.addiw . 2)
    )))
(define rv64_c-rd_rs1_p
  (make-immutable-hash
    '(
      (c.srli . 1)
      (c.srai . 1)
      (c.subw . 1)
      (c.addw . 1)
    )))
(define rv64_c-c_nzuimm6
  (make-immutable-hash
    '(
      (c.srli . 2)
      (c.srai . 2)
      (c.slli . 2)
    )))
(define rv64_c-rd_n0
  (make-immutable-hash
    '(
      (c.ldsp . 1)
    )))
(define rv64_c-c_uimm9sp
  (make-immutable-hash
    '(
      (c.ldsp . 2)
    )))
(define rv64_c-c_rs2
  (make-immutable-hash
    '(
      (c.sdsp . 1)
    )))
(define rv64_c-c_uimm9sp_s
  (make-immutable-hash
    '(
      (c.sdsp . 2)
    )))

(define rv64_c-fields '(rd_p rs1_p c_uimm8 rs2_p rd_rs1_n0 c_imm6 rd_rs1_p c_nzuimm6 rd_n0 c_uimm9sp c_rs2 c_uimm9sp_s))

(define rv64_c-param-count
  (make-immutable-hash
    '(
      (c.ld . 3)
      (c.sd . 3)
      (c.addiw . 2)
      (c.srli . 2)
      (c.srai . 2)
      (c.subw . 2)
      (c.addw . 2)
      (c.slli . 2)
      (c.ldsp . 2)
      (c.sdsp . 2)
    )))

(define rv64_c-operands
  (make-immutable-hash
    '(
      (c.ld . (rd_p rs1_p c_uimm8))
      (c.sd . (rs1_p rs2_p c_uimm8))
      (c.addiw . (rd_rs1_n0 c_imm6))
      (c.srli . (rd_rs1_p c_nzuimm6))
      (c.srai . (rd_rs1_p c_nzuimm6))
      (c.subw . (rd_rs1_p rs2_p))
      (c.addw . (rd_rs1_p rs2_p))
      (c.slli . (rd_rs1_n0 c_nzuimm6))
      (c.ldsp . (rd_n0 c_uimm9sp))
      (c.sdsp . (c_rs2 c_uimm9sp_s))
    )))

(define rv64_c-asm
  (make-immutable-hash
    '(
      (c.ld . "c.ld rd_p, rs1_p, c_uimm8")
      (c.sd . "c.sd rs1_p, rs2_p, c_uimm8")
      (c.addiw . "c.addiw rd_rs1_n0, c_imm6")
      (c.srli . "c.srli rd_rs1_p, c_nzuimm6")
      (c.srai . "c.srai rd_rs1_p, c_nzuimm6")
      (c.subw . "c.subw rd_rs1_p, rs2_p")
      (c.addw . "c.addw rd_rs1_p, rs2_p")
      (c.slli . "c.slli rd_rs1_n0, c_nzuimm6")
      (c.ldsp . "c.ldsp rd_n0, c_uimm9sp")
      (c.sdsp . "c.sdsp c_rs2, c_uimm9sp_s")
    )))

(define rv64_c-operand-types
  (make-immutable-hash
    '(
      (c.ld . (reg reg imm))
      (c.sd . (reg reg imm))
      (c.addiw . (reg imm))
      (c.srli . (reg imm))
      (c.srai . (reg imm))
      (c.subw . (reg reg))
      (c.addw . (reg reg))
      (c.slli . (reg imm))
      (c.ldsp . (reg imm))
      (c.sdsp . (reg imm))
    )))

(define rv64_c-width 16)

;; ====== Helper functions ======

(define (rv64_c-get-param-count mnemonic)
  (hash-ref rv64_c-param-count mnemonic #f))

(define (rv64_c-get-operands mnemonic)
  (hash-ref rv64_c-operands mnemonic '()))

(define (rv64_c-get-asm mnemonic)
  (hash-ref rv64_c-asm mnemonic #f))

(define (rv64_c-get-operand-types mnemonic)
  (hash-ref rv64_c-operand-types mnemonic '()))

(define (rv64_c-get-width) rv64_c-width)

(define (rv64_c-exists? mnemonic)
  (hash-has-key? rv64_c-param-count mnemonic))

(define (rv64_c-get-field-position mnemonic field)
  (case field
    [(rd_p) (hash-ref rv64_c-rd_p mnemonic #f)]
    [(rs1_p) (hash-ref rv64_c-rs1_p mnemonic #f)]
    [(c_uimm8) (hash-ref rv64_c-c_uimm8 mnemonic #f)]
    [(rs2_p) (hash-ref rv64_c-rs2_p mnemonic #f)]
    [(rd_rs1_n0) (hash-ref rv64_c-rd_rs1_n0 mnemonic #f)]
    [(c_imm6) (hash-ref rv64_c-c_imm6 mnemonic #f)]
    [(rd_rs1_p) (hash-ref rv64_c-rd_rs1_p mnemonic #f)]
    [(c_nzuimm6) (hash-ref rv64_c-c_nzuimm6 mnemonic #f)]
    [(rd_n0) (hash-ref rv64_c-rd_n0 mnemonic #f)]
    [(c_uimm9sp) (hash-ref rv64_c-c_uimm9sp mnemonic #f)]
    [(c_rs2) (hash-ref rv64_c-c_rs2 mnemonic #f)]
    [(c_uimm9sp_s) (hash-ref rv64_c-c_uimm9sp_s mnemonic #f)]
    [else #f]))

(provide
  rv64_c-rd_p
  rv64_c-rs1_p
  rv64_c-c_uimm8
  rv64_c-rs2_p
  rv64_c-rd_rs1_n0
  rv64_c-c_imm6
  rv64_c-rd_rs1_p
  rv64_c-c_nzuimm6
  rv64_c-rd_n0
  rv64_c-c_uimm9sp
  rv64_c-c_rs2
  rv64_c-c_uimm9sp_s
  rv64_c-fields
  rv64_c-param-count
  rv64_c-operands
  rv64_c-asm
  rv64_c-operand-types
  rv64_c-width
  rv64_c-get-param-count
  rv64_c-get-operands
  rv64_c-get-asm
  rv64_c-get-operand-types
  rv64_c-get-width
  rv64_c-exists?
  rv64_c-get-field-position)
