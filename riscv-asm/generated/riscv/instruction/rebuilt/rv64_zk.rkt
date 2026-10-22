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

(define rolw
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 25 31 48) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 14) (bit-range-fixed 0 1 3))))
(define rorw
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 25 31 48) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 14) (bit-range-fixed 0 1 3))))
(define roriw
  (make-instruction
   (list raw:rd raw:rs1 raw:shamtw)
   (list (bit-range-fixed 25 31 48) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 6) (bit-range-fixed 0 1 3))))
(define rori
  (make-instruction
   (list raw:rd raw:rs1 raw:shamtd)
   (list (bit-range-fixed 26 31 24) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define packw
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 25 31 4) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 14) (bit-range-fixed 0 1 3))))
(define aes64esm
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 30 31 0) (bit-range-fixed 25 29 27) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 51))))
(define aes64es
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 30 31 0) (bit-range-fixed 25 29 25) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 51))))
(define aes64ks1i
  (make-instruction
   (list raw:rd raw:rs1 raw:rnum)
   (list (bit-range-fixed 30 31 0) (bit-range-fixed 25 29 24) (bit-range-fixed 24 24 1) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 19))))
(define aes64ks2
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 30 31 1) (bit-range-fixed 25 29 31) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 51))))
(define aes64dsm
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 30 31 0) (bit-range-fixed 25 29 31) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 51))))
(define aes64ds
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 30 31 0) (bit-range-fixed 25 29 29) (bit-range-fixed 12 14 0) (bit-range-fixed 0 6 51))))
(define aes64im
  (make-instruction
   (list raw:rd raw:rs1)
   (list (bit-range-fixed 30 31 0) (bit-range-fixed 25 29 24) (bit-range-fixed 20 24 0) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 19))))
(define sha512sum0
  (make-instruction
   (list raw:rd raw:rs1)
   (list (bit-range-fixed 30 31 0) (bit-range-fixed 25 29 8) (bit-range-fixed 20 24 4) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 19))))
(define sha512sum1
  (make-instruction
   (list raw:rd raw:rs1)
   (list (bit-range-fixed 30 31 0) (bit-range-fixed 25 29 8) (bit-range-fixed 20 24 5) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 19))))
(define sha512sig0
  (make-instruction
   (list raw:rd raw:rs1)
   (list (bit-range-fixed 30 31 0) (bit-range-fixed 25 29 8) (bit-range-fixed 20 24 6) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 19))))
(define sha512sig1
  (make-instruction
   (list raw:rd raw:rs1)
   (list (bit-range-fixed 30 31 0) (bit-range-fixed 25 29 8) (bit-range-fixed 20 24 7) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 19))))
(define rev8
  (make-instruction
   (list raw:rd raw:rs1)
   (list (bit-range-fixed 20 31 1720) (bit-range-fixed 12 14 5) (bit-range-fixed 0 6 19))))

(provide
 rolw
 rorw
 roriw
 rori
 packw
 aes64esm
 aes64es
 aes64ks1i
 aes64ks2
 aes64dsm
 aes64ds
 aes64im
 sha512sum0
 sha512sum1
 sha512sig0
 sha512sig1
 rev8)
