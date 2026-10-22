#lang racket

(define rv_zicsr-rd
  (make-immutable-hash
    '(
      (csrrw . 1)
      (csrrs . 1)
      (csrrc . 1)
      (csrrwi . 1)
      (csrrsi . 1)
      (csrrci . 1)
    )))
(define rv_zicsr-rs1
  (make-immutable-hash
    '(
      (csrrw . 2)
      (csrrs . 2)
      (csrrc . 2)
    )))
(define rv_zicsr-csr
  (make-immutable-hash
    '(
      (csrrw . 3)
      (csrrs . 3)
      (csrrc . 3)
      (csrrwi . 2)
      (csrrsi . 2)
      (csrrci . 2)
    )))
(define rv_zicsr-zimm5
  (make-immutable-hash
    '(
      (csrrwi . 3)
      (csrrsi . 3)
      (csrrci . 3)
    )))

(define rv_zicsr-fields '(rd rs1 csr zimm5))

(define rv_zicsr-param-count
  (make-immutable-hash
    '(
      (csrrw . 3)
      (csrrs . 3)
      (csrrc . 3)
      (csrrwi . 3)
      (csrrsi . 3)
      (csrrci . 3)
    )))

(define rv_zicsr-operands
  (make-immutable-hash
    '(
      (csrrw . (rd rs1 csr))
      (csrrs . (rd rs1 csr))
      (csrrc . (rd rs1 csr))
      (csrrwi . (rd csr zimm5))
      (csrrsi . (rd csr zimm5))
      (csrrci . (rd csr zimm5))
    )))

(define rv_zicsr-asm
  (make-immutable-hash
    '(
      (csrrw . "csrrw rd, rs1, csr")
      (csrrs . "csrrs rd, rs1, csr")
      (csrrc . "csrrc rd, rs1, csr")
      (csrrwi . "csrrwi rd, csr, zimm5")
      (csrrsi . "csrrsi rd, csr, zimm5")
      (csrrci . "csrrci rd, csr, zimm5")
    )))

(define rv_zicsr-operand-types
  (make-immutable-hash
    '(
      (csrrw . (reg reg csr))
      (csrrs . (reg reg csr))
      (csrrc . (reg reg csr))
      (csrrwi . (reg csr imm))
      (csrrsi . (reg csr imm))
      (csrrci . (reg csr imm))
    )))

(define rv_zicsr-width 32)

;; ====== Helper functions ======

(define (rv_zicsr-get-param-count mnemonic)
  (hash-ref rv_zicsr-param-count mnemonic #f))

(define (rv_zicsr-get-operands mnemonic)
  (hash-ref rv_zicsr-operands mnemonic '()))

(define (rv_zicsr-get-asm mnemonic)
  (hash-ref rv_zicsr-asm mnemonic #f))

(define (rv_zicsr-get-operand-types mnemonic)
  (hash-ref rv_zicsr-operand-types mnemonic '()))

(define (rv_zicsr-get-width) rv_zicsr-width)

(define (rv_zicsr-exists? mnemonic)
  (hash-has-key? rv_zicsr-param-count mnemonic))

(define (rv_zicsr-get-field-position mnemonic field)
  (case field
    [(rd) (hash-ref rv_zicsr-rd mnemonic #f)]
    [(rs1) (hash-ref rv_zicsr-rs1 mnemonic #f)]
    [(csr) (hash-ref rv_zicsr-csr mnemonic #f)]
    [(zimm5) (hash-ref rv_zicsr-zimm5 mnemonic #f)]
    [else #f]))

(provide
  rv_zicsr-rd
  rv_zicsr-rs1
  rv_zicsr-csr
  rv_zicsr-zimm5
  rv_zicsr-fields
  rv_zicsr-param-count
  rv_zicsr-operands
  rv_zicsr-asm
  rv_zicsr-operand-types
  rv_zicsr-width
  rv_zicsr-get-param-count
  rv_zicsr-get-operands
  rv_zicsr-get-asm
  rv_zicsr-get-operand-types
  rv_zicsr-get-width
  rv_zicsr-exists?
  rv_zicsr-get-field-position)
