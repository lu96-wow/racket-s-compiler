#lang racket

(define rv_zfhmin-rd
  (make-immutable-hash
    '(
      (flh . 1)
      (fcvt.s.h . 1)
      (fcvt.h.s . 1)
      (fmv.x.h . 1)
      (fmv.h.x . 1)
    )))
(define rv_zfhmin-rs1
  (make-immutable-hash
    '(
      (flh . 2)
      (fsh . 2)
      (fcvt.s.h . 2)
      (fcvt.h.s . 2)
      (fmv.x.h . 2)
      (fmv.h.x . 2)
    )))
(define rv_zfhmin-imm12
  (make-immutable-hash
    '(
      (flh . 3)
    )))
(define rv_zfhmin-simm12
  (make-immutable-hash
    '(
      (fsh . 1)
    )))
(define rv_zfhmin-rs2
  (make-immutable-hash
    '(
      (fsh . 3)
    )))
(define rv_zfhmin-rm
  (make-immutable-hash
    '(
      (fcvt.s.h . 3)
      (fcvt.h.s . 3)
    )))

(define rv_zfhmin-fields '(rd rs1 imm12 simm12 rs2 rm))

(define rv_zfhmin-param-count
  (make-immutable-hash
    '(
      (flh . 3)
      (fsh . 3)
      (fcvt.s.h . 3)
      (fcvt.h.s . 3)
      (fmv.x.h . 2)
      (fmv.h.x . 2)
    )))

(define rv_zfhmin-operands
  (make-immutable-hash
    '(
      (flh . (rd rs1 imm12))
      (fsh . (simm12 rs1 rs2))
      (fcvt.s.h . (rd rs1 rm))
      (fcvt.h.s . (rd rs1 rm))
      (fmv.x.h . (rd rs1))
      (fmv.h.x . (rd rs1))
    )))

(define rv_zfhmin-asm
  (make-immutable-hash
    '(
      (flh . "flh rd, rs1, imm12")
      (fsh . "fsh simm12, rs1, rs2")
      (fcvt.s.h . "fcvt.s.h rd, rs1, rm")
      (fcvt.h.s . "fcvt.h.s rd, rs1, rm")
      (fmv.x.h . "fmv.x.h rd, rs1")
      (fmv.h.x . "fmv.h.x rd, rs1")
    )))

(define rv_zfhmin-operand-types
  (make-immutable-hash
    '(
      (flh . (reg reg imm))
      (fsh . (imm reg reg))
      (fcvt.s.h . (reg reg imm))
      (fcvt.h.s . (reg reg imm))
      (fmv.x.h . (reg reg))
      (fmv.h.x . (reg reg))
    )))

(define rv_zfhmin-width 32)

;; ====== Helper functions ======

(define (rv_zfhmin-get-param-count mnemonic)
  (hash-ref rv_zfhmin-param-count mnemonic #f))

(define (rv_zfhmin-get-operands mnemonic)
  (hash-ref rv_zfhmin-operands mnemonic '()))

(define (rv_zfhmin-get-asm mnemonic)
  (hash-ref rv_zfhmin-asm mnemonic #f))

(define (rv_zfhmin-get-operand-types mnemonic)
  (hash-ref rv_zfhmin-operand-types mnemonic '()))

(define (rv_zfhmin-get-width) rv_zfhmin-width)

(define (rv_zfhmin-exists? mnemonic)
  (hash-has-key? rv_zfhmin-param-count mnemonic))

(define (rv_zfhmin-get-field-position mnemonic field)
  (case field
    [(rd) (hash-ref rv_zfhmin-rd mnemonic #f)]
    [(rs1) (hash-ref rv_zfhmin-rs1 mnemonic #f)]
    [(imm12) (hash-ref rv_zfhmin-imm12 mnemonic #f)]
    [(simm12) (hash-ref rv_zfhmin-simm12 mnemonic #f)]
    [(rs2) (hash-ref rv_zfhmin-rs2 mnemonic #f)]
    [(rm) (hash-ref rv_zfhmin-rm mnemonic #f)]
    [else #f]))

(provide
  rv_zfhmin-rd
  rv_zfhmin-rs1
  rv_zfhmin-imm12
  rv_zfhmin-simm12
  rv_zfhmin-rs2
  rv_zfhmin-rm
  rv_zfhmin-fields
  rv_zfhmin-param-count
  rv_zfhmin-operands
  rv_zfhmin-asm
  rv_zfhmin-operand-types
  rv_zfhmin-width
  rv_zfhmin-get-param-count
  rv_zfhmin-get-operands
  rv_zfhmin-get-asm
  rv_zfhmin-get-operand-types
  rv_zfhmin-get-width
  rv_zfhmin-exists?
  rv_zfhmin-get-field-position)
