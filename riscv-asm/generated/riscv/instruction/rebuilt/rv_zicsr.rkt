#lang racket/base

(require "../../../base.rkt"
         (prefix-in raw: "../../raw/scalar.rkt")
         (prefix-in raw: "../../raw/compressed.rkt")
         (prefix-in raw: "../../raw/vector.rkt")
         (prefix-in raw: "../../raw/mop.rkt")
         (prefix-in rebuilt: "../../rebuilt/scalar.rkt")
         (prefix-in rebuilt: "../../rebuilt/compressed.rkt")
         (prefix-in rebuilt: "../../rebuilt/vector.rkt")
         (prefix-in rebuilt: "../../rebuilt/mop.rkt"))

(define csrrw
  (make-instruction
   (list raw:rd raw:rs1 raw:csr)
   (list (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define csrrs
  (make-instruction
   (list raw:rd raw:rs1 raw:csr)
   (list (bit-range-fixed 12 14 2) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define csrrc
  (make-instruction
   (list raw:rd raw:rs1 raw:csr)
   (list (bit-range-fixed 12 14 3) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define csrrwi
  (make-instruction
   (list raw:rd raw:csr raw:zimm5)
   (list (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define csrrsi
  (make-instruction
   (list raw:rd raw:csr raw:zimm5)
   (list (bit-range-fixed 12 14 6) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define csrrci
  (make-instruction
   (list raw:rd raw:csr raw:zimm5)
   (list (bit-range-fixed 12 14 7) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define csrr
  (make-instruction
   (list raw:rd raw:csr)
   (list (bit-range-fixed 15 19 0) (bit-range-fixed 12 14 2) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define csrw
  (make-instruction
   (list raw:rs1 raw:csr)
   (list (bit-range-fixed 12 14 1) (bit-range-fixed 7 11 0) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define csrs
  (make-instruction
   (list raw:rs1 raw:csr)
   (list (bit-range-fixed 12 14 2) (bit-range-fixed 7 11 0) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define csrc
  (make-instruction
   (list raw:rs1 raw:csr)
   (list (bit-range-fixed 12 14 3) (bit-range-fixed 7 11 0) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define csrwi
  (make-instruction
   (list raw:csr raw:zimm5)
   (list (bit-range-fixed 12 14 5) (bit-range-fixed 7 11 0) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define csrsi
  (make-instruction
   (list raw:csr raw:zimm5)
   (list (bit-range-fixed 12 14 6) (bit-range-fixed 7 11 0) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define csrci
  (make-instruction
   (list raw:csr raw:zimm5)
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
