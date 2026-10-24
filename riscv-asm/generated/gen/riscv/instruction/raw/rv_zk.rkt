#lang racket/base

(require "../../../../lib/base.rkt"
         "../../../../lib/riscv/raw/scalar.rkt"
         "../../../../lib/riscv/raw/compressed.rkt"
         "../../../../lib/riscv/raw/vector.rkt"
         "../../../../lib/riscv/raw/mop.rkt")

(define rol
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 25 31 48) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define ror
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 25 31 48) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define andn
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 25 31 32) (bit-range-fixed 12 14 7) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define orn
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 25 31 32) (bit-range-fixed 12 14 6) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define xnor
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 25 31 32) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define pack
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 25 31 4) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define packh
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 25 31 4) (bit-range-fixed 12 14 7) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define clmul
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 25 31 5) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define clmulh
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 25 31 5) (bit-range-fixed 12 14 3) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define xperm4
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 25 31 20) (bit-range-fixed 12 14 2) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define xperm8
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 25 31 20) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define sha256sum0
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 30 31 0) (bit-range-fixed 25 29 8) (bit-range-fixed 20 24 0) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 19))))
(define sha256sum1
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 30 31 0) (bit-range-fixed 25 29 8) (bit-range-fixed 20 24 1) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 19))))
(define sha256sig0
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 30 31 0) (bit-range-fixed 25 29 8) (bit-range-fixed 20 24 2) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 19))))
(define sha256sig1
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 30 31 0) (bit-range-fixed 25 29 8) (bit-range-fixed 20 24 3) (bit-range-fixed 12 14 1) (bit-range-fixed 0 6 19))))
(define brev8
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 20 31 1671) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))

(provide
 rol
 ror
 andn
 orn
 xnor
 pack
 packh
 clmul
 clmulh
 xperm4
 xperm8
 sha256sum0
 sha256sum1
 sha256sig0
 sha256sig1
 brev8)
