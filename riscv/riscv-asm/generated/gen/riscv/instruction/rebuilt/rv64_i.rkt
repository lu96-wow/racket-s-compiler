#lang racket/base

(require "../../../../lib/base.rkt"
         (prefix-in raw: "../../../../lib/riscv/raw/scalar.rkt")
         (prefix-in raw: "../../../../lib/riscv/raw/compressed.rkt")
         (prefix-in raw: "../../../../lib/riscv/raw/vector.rkt")
         (prefix-in raw: "../../../../lib/riscv/raw/mop.rkt")
         (prefix-in rebuilt: "../../field/rebuilt/scalar.rkt")
         (prefix-in rebuilt: "../../field/rebuilt/compressed.rkt")
         (prefix-in rebuilt: "../../field/rebuilt/vector.rkt")
         (prefix-in rebuilt: "../../field/rebuilt/mop.rkt"))

(define lwu
  (make-instruction
   (list raw:rd raw:rs1 raw:imm12)
   (list (bit-range-fixed 12 14 6) (bit-range-fixed 2 6 0) (bit-range-fixed 0 1 3))))
(define ld
  (make-instruction
   (list raw:rd raw:rs1 raw:imm12)
   (list (bit-range-fixed 12 14 3) (bit-range-fixed 2 6 0) (bit-range-fixed 0 1 3))))
(define sd
  (let ([encode (make-instruction
   (list rebuilt:simm12 raw:rs1 raw:rs2 rebuilt:simm12)
   (list (bit-range-fixed 12 14 3) (bit-range-fixed 2 6 8) (bit-range-fixed 0 1 3)))])
    (lambda (simm12 rs1 rs2)
      (encode simm12 rs1 rs2 simm12))))
(define slli
  (make-instruction
   (list raw:rd raw:rs1 raw:shamtd)
   (list (bit-range-fixed 26 31 0) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define srli
  (make-instruction
   (list raw:rd raw:rs1 raw:shamtd)
   (list (bit-range-fixed 26 31 0) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define srai
  (make-instruction
   (list raw:rd raw:rs1 raw:shamtd)
   (list (bit-range-fixed 26 31 16) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define addiw
  (make-instruction
   (list raw:rd raw:rs1 raw:imm12)
   (list (bit-range-fixed 12 14 0) (bit-range-fixed 2 6 6) (bit-range-fixed 0 1 3))))
(define slliw
  (make-instruction
   (list raw:rd raw:rs1 raw:shamtw)
   (list (bit-range-fixed 25 31 0) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 6) (bit-range-fixed 0 1 3))))
(define srliw
  (make-instruction
   (list raw:rd raw:rs1 raw:shamtw)
   (list (bit-range-fixed 25 31 0) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 6) (bit-range-fixed 0 1 3))))
(define sraiw
  (make-instruction
   (list raw:rd raw:rs1 raw:shamtw)
   (list (bit-range-fixed 25 31 32) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 6) (bit-range-fixed 0 1 3))))
(define addw
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 25 31 0) (bit-range-fixed 12 14 0) (bit-range-fixed 2 6 14) (bit-range-fixed 0 1 3))))
(define subw
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 25 31 32) (bit-range-fixed 12 14 0) (bit-range-fixed 2 6 14) (bit-range-fixed 0 1 3))))
(define sllw
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 25 31 0) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 14) (bit-range-fixed 0 1 3))))
(define srlw
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 25 31 0) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 14) (bit-range-fixed 0 1 3))))
(define sraw
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 25 31 32) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 14) (bit-range-fixed 0 1 3))))
(define sext.w
  (make-instruction
   (list raw:rd raw:rs1)
   (list (bit-range-fixed 20 31 0) (bit-range-fixed 12 14 0) (bit-range-fixed 2 6 6) (bit-range-fixed 0 1 3))))

(provide
 lwu
 ld
 sd
 slli
 srli
 srai
 addiw
 slliw
 srliw
 sraiw
 addw
 subw
 sllw
 srlw
 sraw
 sext.w)
