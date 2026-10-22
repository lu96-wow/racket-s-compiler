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

(define aes32esmi
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2 raw:bs)
   (list (bit-range-fixed 25 29 19) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 51))))
(define aes32esi
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2 raw:bs)
   (list (bit-range-fixed 25 29 17) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 51))))
(define aes32dsmi
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2 raw:bs)
   (list (bit-range-fixed 25 29 23) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 51))))
(define aes32dsi
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2 raw:bs)
   (list (bit-range-fixed 25 29 21) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 51))))
(define sha512sum0r
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 30 31 1) (bit-range-fixed 25 29 8) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 51))))
(define sha512sum1r
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 30 31 1) (bit-range-fixed 25 29 9) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 51))))
(define sha512sig0l
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 30 31 1) (bit-range-fixed 25 29 10) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 51))))
(define sha512sig0h
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 30 31 1) (bit-range-fixed 25 29 14) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 51))))
(define sha512sig1l
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 30 31 1) (bit-range-fixed 25 29 11) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 51))))
(define sha512sig1h
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 30 31 1) (bit-range-fixed 25 29 15) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 51))))
(define zip
  (make-instruction
   (list raw:rd raw:rs1)
   (list (bit-range-fixed 25 31 4) (bit-range-fixed 20 24 15) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define unzip
  (make-instruction
   (list raw:rd raw:rs1)
   (list (bit-range-fixed 25 31 4) (bit-range-fixed 20 24 15) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define rori.rv32
  (make-instruction
   (list raw:rd raw:rs1 raw:shamtw)
   (list (bit-range-fixed 25 31 48) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define rev8.rv32
  (make-instruction
   (list raw:rd raw:rs1)
   (list (bit-range-fixed 20 31 1688) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 19))))

(provide
 aes32esmi
 aes32esi
 aes32dsmi
 aes32dsi
 sha512sum0r
 sha512sum1r
 sha512sig0l
 sha512sig0h
 sha512sig1l
 sha512sig1h
 zip
 unzip
 rori.rv32
 rev8.rv32)
