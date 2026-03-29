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

(define rv64_i-fields '(rd rs1 imm12 rs2 shamtd shamtw ))

(provide
  rv64_i-rd
  rv64_i-rs1
  rv64_i-imm12
  rv64_i-rs2
  rv64_i-shamtd
  rv64_i-shamtw
  rv64_i-fields)
