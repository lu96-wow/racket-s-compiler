#lang racket

(define rv64_i-rd
  (make-immutable-hash
    '(
      (lwu . 1)
      (ld . 1)
      (slli . 1)
      (srli . 1)
      (srai . 1)
      (addiw . 1)
      (slliw . 1)
      (srliw . 1)
      (sraiw . 1)
      (addw . 1)
      (subw . 1)
      (sllw . 1)
      (srlw . 1)
      (sraw . 1)
    )))
(define rv64_i-rs1
  (make-immutable-hash
    '(
      (lwu . 2)
      (ld . 2)
      (sd . 2)
      (slli . 2)
      (srli . 2)
      (srai . 2)
      (addiw . 2)
      (slliw . 2)
      (srliw . 2)
      (sraiw . 2)
      (addw . 2)
      (subw . 2)
      (sllw . 2)
      (srlw . 2)
      (sraw . 2)
    )))
(define rv64_i-imm12
  (make-immutable-hash
    '(
      (lwu . 3)
      (ld . 3)
      (sd . 1)
      (addiw . 3)
    )))
(define rv64_i-rs2
  (make-immutable-hash
    '(
      (sd . 3)
      (addw . 3)
      (subw . 3)
      (sllw . 3)
      (srlw . 3)
      (sraw . 3)
    )))
(define rv64_i-shamtd
  (make-immutable-hash
    '(
      (slli . 3)
      (srli . 3)
      (srai . 3)
    )))
(define rv64_i-shamtw
  (make-immutable-hash
    '(
      (slliw . 3)
      (srliw . 3)
      (sraiw . 3)
    )))

(define rv64_i-fields '(rd rs1 imm12 rs2 shamtd shamtw))

(define rv64_i-param-count
  (make-immutable-hash
    '(
      (lwu . 3)
      (ld . 3)
      (sd . 3)
      (slli . 3)
      (srli . 3)
      (srai . 3)
      (addiw . 3)
      (slliw . 3)
      (srliw . 3)
      (sraiw . 3)
      (addw . 3)
      (subw . 3)
      (sllw . 3)
      (srlw . 3)
      (sraw . 3)
    )))

(define rv64_i-operands
  (make-immutable-hash
    '(
      (lwu . (rd rs1 imm12))
      (ld . (rd rs1 imm12))
      (sd . (imm12 rs1 rs2))
      (slli . (rd rs1 shamtd))
      (srli . (rd rs1 shamtd))
      (srai . (rd rs1 shamtd))
      (addiw . (rd rs1 imm12))
      (slliw . (rd rs1 shamtw))
      (srliw . (rd rs1 shamtw))
      (sraiw . (rd rs1 shamtw))
      (addw . (rd rs1 rs2))
      (subw . (rd rs1 rs2))
      (sllw . (rd rs1 rs2))
      (srlw . (rd rs1 rs2))
      (sraw . (rd rs1 rs2))
    )))

(define rv64_i-asm
  (make-immutable-hash
    '(
      (lwu . "lwu rd, rs1, imm12")
      (ld . "ld rd, rs1, imm12")
      (sd . "sd imm12, rs1, rs2")
      (slli . "slli rd, rs1, shamtd")
      (srli . "srli rd, rs1, shamtd")
      (srai . "srai rd, rs1, shamtd")
      (addiw . "addiw rd, rs1, imm12")
      (slliw . "slliw rd, rs1, shamtw")
      (srliw . "srliw rd, rs1, shamtw")
      (sraiw . "sraiw rd, rs1, shamtw")
      (addw . "addw rd, rs1, rs2")
      (subw . "subw rd, rs1, rs2")
      (sllw . "sllw rd, rs1, rs2")
      (srlw . "srlw rd, rs1, rs2")
      (sraw . "sraw rd, rs1, rs2")
    )))

(define rv64_i-operand-types
  (make-immutable-hash
    '(
      (lwu . (reg reg imm))
      (ld . (reg reg imm))
      (sd . (imm reg reg))
      (slli . (reg reg imm))
      (srli . (reg reg imm))
      (srai . (reg reg imm))
      (addiw . (reg reg imm))
      (slliw . (reg reg imm))
      (srliw . (reg reg imm))
      (sraiw . (reg reg imm))
      (addw . (reg reg reg))
      (subw . (reg reg reg))
      (sllw . (reg reg reg))
      (srlw . (reg reg reg))
      (sraw . (reg reg reg))
    )))

(define rv64_i-width 32)

;; ====== Helper functions ======

(define (rv64_i-get-param-count mnemonic)
  (hash-ref rv64_i-param-count mnemonic #f))

(define (rv64_i-get-operands mnemonic)
  (hash-ref rv64_i-operands mnemonic '()))

(define (rv64_i-get-asm mnemonic)
  (hash-ref rv64_i-asm mnemonic #f))

(define (rv64_i-get-operand-types mnemonic)
  (hash-ref rv64_i-operand-types mnemonic '()))

(define (rv64_i-get-width) rv64_i-width)

(define (rv64_i-exists? mnemonic)
  (hash-has-key? rv64_i-param-count mnemonic))

(define (rv64_i-get-field-position mnemonic field)
  (case field
    [(rd) (hash-ref rv64_i-rd mnemonic #f)]
    [(rs1) (hash-ref rv64_i-rs1 mnemonic #f)]
    [(imm12) (hash-ref rv64_i-imm12 mnemonic #f)]
    [(rs2) (hash-ref rv64_i-rs2 mnemonic #f)]
    [(shamtd) (hash-ref rv64_i-shamtd mnemonic #f)]
    [(shamtw) (hash-ref rv64_i-shamtw mnemonic #f)]
    [else #f]))

(provide
  rv64_i-rd
  rv64_i-rs1
  rv64_i-imm12
  rv64_i-rs2
  rv64_i-shamtd
  rv64_i-shamtw
  rv64_i-fields
  rv64_i-param-count
  rv64_i-operands
  rv64_i-asm
  rv64_i-operand-types
  rv64_i-width
  rv64_i-get-param-count
  rv64_i-get-operands
  rv64_i-get-asm
  rv64_i-get-operand-types
  rv64_i-get-width
  rv64_i-exists?
  rv64_i-get-field-position)
