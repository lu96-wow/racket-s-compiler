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

(define rv_zicsr-fields '(rd rs1 csr zimm5 ))

(provide
  rv_zicsr-rd
  rv_zicsr-rs1
  rv_zicsr-csr
  rv_zicsr-zimm5
  rv_zicsr-fields)
