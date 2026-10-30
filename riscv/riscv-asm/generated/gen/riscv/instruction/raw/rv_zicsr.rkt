#lang racket/base

(require "../../../../lib/base.rkt"
         "../../../../lib/riscv/raw/scalar.rkt"
         "../../../../lib/riscv/raw/compressed.rkt"
         "../../../../lib/riscv/raw/vector.rkt"
         "../../../../lib/riscv/raw/mop.rkt")

(define csrrw
  (make-instruction
   (list rd rs1 csr)
   (list (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define csrrs
  (make-instruction
   (list rd rs1 csr)
   (list (bit-range-fixed 12 14 2) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define csrrc
  (make-instruction
   (list rd rs1 csr)
   (list (bit-range-fixed 12 14 3) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define csrrwi
  (make-instruction
   (list rd csr zimm5)
   (list (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define csrrsi
  (make-instruction
   (list rd csr zimm5)
   (list (bit-range-fixed 12 14 6) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define csrrci
  (make-instruction
   (list rd csr zimm5)
   (list (bit-range-fixed 12 14 7) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define csrr
  (make-instruction
   (list rd csr)
   (list (bit-range-fixed 15 19 0) (bit-range-fixed 12 14 2) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define csrw
  (make-instruction
   (list rs1 csr)
   (list (bit-range-fixed 12 14 1) (bit-range-fixed 7 11 0) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define csrs
  (make-instruction
   (list rs1 csr)
   (list (bit-range-fixed 12 14 2) (bit-range-fixed 7 11 0) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define csrc
  (make-instruction
   (list rs1 csr)
   (list (bit-range-fixed 12 14 3) (bit-range-fixed 7 11 0) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define csrwi
  (make-instruction
   (list csr zimm5)
   (list (bit-range-fixed 12 14 5) (bit-range-fixed 7 11 0) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define csrsi
  (make-instruction
   (list csr zimm5)
   (list (bit-range-fixed 12 14 6) (bit-range-fixed 7 11 0) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define csrci
  (make-instruction
   (list csr zimm5)
   (list (bit-range-fixed 12 14 7) (bit-range-fixed 7 11 0) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))

(provide
 csrrw
 csrrs
 csrrc
 csrrwi
 csrrsi
 csrrci
 csrr
 csrw
 csrs
 csrc
 csrwi
 csrsi
 csrci)
