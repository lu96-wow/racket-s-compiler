#lang racket/base

(require "../../../../lib/base.rkt"
         (prefix-in raw: "../../../../lib/riscv/raw/scalar.rkt")
         (prefix-in raw: "../../../../lib/riscv/raw/compressed.rkt")
         (prefix-in raw: "../../../../lib/riscv/raw/vector.rkt")
         (prefix-in raw: "../../../../lib/riscv/raw/mop.rkt")
         (prefix-in rebuilt: "../../../../lib/riscv/rebuilt/scalar.rkt")
         (prefix-in rebuilt: "../../../../lib/riscv/rebuilt/compressed.rkt")
         (prefix-in rebuilt: "../../../../lib/riscv/rebuilt/vector.rkt")
         (prefix-in rebuilt: "../../../../lib/riscv/rebuilt/mop.rkt"))

(define lui
  (make-instruction
   (list raw:rd raw:imm20)
   (list (bit-range-fixed 2 6 13) (bit-range-fixed 0 1 3))))
(define auipc
  (make-instruction
   (list raw:rd raw:imm20)
   (list (bit-range-fixed 2 6 5) (bit-range-fixed 0 1 3))))
(define jal
  (make-instruction
   (list raw:rd raw:jimm20)
   (list (bit-range-fixed 2 6 27) (bit-range-fixed 0 1 3))))
(define jalr
  (make-instruction
   (list raw:rd raw:rs1 raw:imm12)
   (list (bit-range-fixed 12 14 0) (bit-range-fixed 2 6 25) (bit-range-fixed 0 1 3))))
(define beq
  (let ([encode (make-instruction
   (list rebuilt:bimm12 raw:rs1 raw:rs2 rebuilt:bimm12)
   (list (bit-range-fixed 12 14 0) (bit-range-fixed 2 6 24) (bit-range-fixed 0 1 3)))])
    (lambda (bimm12 rs1 rs2)
      (encode bimm12 rs1 rs2 bimm12))))
(define bne
  (let ([encode (make-instruction
   (list rebuilt:bimm12 raw:rs1 raw:rs2 rebuilt:bimm12)
   (list (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 24) (bit-range-fixed 0 1 3)))])
    (lambda (bimm12 rs1 rs2)
      (encode bimm12 rs1 rs2 bimm12))))
(define blt
  (let ([encode (make-instruction
   (list rebuilt:bimm12 raw:rs1 raw:rs2 rebuilt:bimm12)
   (list (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 24) (bit-range-fixed 0 1 3)))])
    (lambda (bimm12 rs1 rs2)
      (encode bimm12 rs1 rs2 bimm12))))
(define bge
  (let ([encode (make-instruction
   (list rebuilt:bimm12 raw:rs1 raw:rs2 rebuilt:bimm12)
   (list (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 24) (bit-range-fixed 0 1 3)))])
    (lambda (bimm12 rs1 rs2)
      (encode bimm12 rs1 rs2 bimm12))))
(define bltu
  (let ([encode (make-instruction
   (list rebuilt:bimm12 raw:rs1 raw:rs2 rebuilt:bimm12)
   (list (bit-range-fixed 12 14 6) (bit-range-fixed 2 6 24) (bit-range-fixed 0 1 3)))])
    (lambda (bimm12 rs1 rs2)
      (encode bimm12 rs1 rs2 bimm12))))
(define bgeu
  (let ([encode (make-instruction
   (list rebuilt:bimm12 raw:rs1 raw:rs2 rebuilt:bimm12)
   (list (bit-range-fixed 12 14 7) (bit-range-fixed 2 6 24) (bit-range-fixed 0 1 3)))])
    (lambda (bimm12 rs1 rs2)
      (encode bimm12 rs1 rs2 bimm12))))
(define lb
  (make-instruction
   (list raw:rd raw:rs1 raw:imm12)
   (list (bit-range-fixed 12 14 0) (bit-range-fixed 2 6 0) (bit-range-fixed 0 1 3))))
(define lh
  (make-instruction
   (list raw:rd raw:rs1 raw:imm12)
   (list (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 0) (bit-range-fixed 0 1 3))))
(define lw
  (make-instruction
   (list raw:rd raw:rs1 raw:imm12)
   (list (bit-range-fixed 12 14 2) (bit-range-fixed 2 6 0) (bit-range-fixed 0 1 3))))
(define lbu
  (make-instruction
   (list raw:rd raw:rs1 raw:imm12)
   (list (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 0) (bit-range-fixed 0 1 3))))
(define lhu
  (make-instruction
   (list raw:rd raw:rs1 raw:imm12)
   (list (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 0) (bit-range-fixed 0 1 3))))
(define sb
  (let ([encode (make-instruction
   (list rebuilt:simm12 raw:rs1 raw:rs2 rebuilt:simm12)
   (list (bit-range-fixed 12 14 0) (bit-range-fixed 2 6 8) (bit-range-fixed 0 1 3)))])
    (lambda (simm12 rs1 rs2)
      (encode simm12 rs1 rs2 simm12))))
(define sh
  (let ([encode (make-instruction
   (list rebuilt:simm12 raw:rs1 raw:rs2 rebuilt:simm12)
   (list (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 8) (bit-range-fixed 0 1 3)))])
    (lambda (simm12 rs1 rs2)
      (encode simm12 rs1 rs2 simm12))))
(define sw
  (let ([encode (make-instruction
   (list rebuilt:simm12 raw:rs1 raw:rs2 rebuilt:simm12)
   (list (bit-range-fixed 12 14 2) (bit-range-fixed 2 6 8) (bit-range-fixed 0 1 3)))])
    (lambda (simm12 rs1 rs2)
      (encode simm12 rs1 rs2 simm12))))
(define addi
  (make-instruction
   (list raw:rd raw:rs1 raw:imm12)
   (list (bit-range-fixed 12 14 0) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define slti
  (make-instruction
   (list raw:rd raw:rs1 raw:imm12)
   (list (bit-range-fixed 12 14 2) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define sltiu
  (make-instruction
   (list raw:rd raw:rs1 raw:imm12)
   (list (bit-range-fixed 12 14 3) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define xori
  (make-instruction
   (list raw:rd raw:rs1 raw:imm12)
   (list (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define ori
  (make-instruction
   (list raw:rd raw:rs1 raw:imm12)
   (list (bit-range-fixed 12 14 6) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define andi
  (make-instruction
   (list raw:rd raw:rs1 raw:imm12)
   (list (bit-range-fixed 12 14 7) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define add
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 25 31 0) (bit-range-fixed 12 14 0) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define sub
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 25 31 32) (bit-range-fixed 12 14 0) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define sll
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 25 31 0) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define slt
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 25 31 0) (bit-range-fixed 12 14 2) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define sltu
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 25 31 0) (bit-range-fixed 12 14 3) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define xor
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 25 31 0) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define srl
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 25 31 0) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define sra
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 25 31 32) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define or
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 25 31 0) (bit-range-fixed 12 14 6) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define and
  (make-instruction
   (list raw:rd raw:rs1 raw:rs2)
   (list (bit-range-fixed 25 31 0) (bit-range-fixed 12 14 7) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define fence
  (make-instruction
   (list raw:fm raw:pred raw:succ raw:rs1 raw:rd)
   (list (bit-range-fixed 12 14 0) (bit-range-fixed 2 6 3) (bit-range-fixed 0 1 3))))
(define ecall
  (make-instruction
   (list)
   (list (bit-range-fixed 20 31 0) (bit-range-fixed 7 19 0) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define ebreak
  (make-instruction
   (list)
   (list (bit-range-fixed 20 31 1) (bit-range-fixed 7 19 0) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define fence.tso
  (make-instruction
   (list raw:rs1 raw:rd)
   (list (bit-range-fixed 28 31 8) (bit-range-fixed 24 27 3) (bit-range-fixed 20 23 3) (bit-range-fixed 12 14 0) (bit-range-fixed 2 6 3) (bit-range-fixed 0 1 3))))
(define pause
  (make-instruction
   (list)
   (list (bit-range-fixed 28 31 0) (bit-range-fixed 24 27 1) (bit-range-fixed 20 23 0) (bit-range-fixed 15 19 0) (bit-range-fixed 12 14 0) (bit-range-fixed 7 11 0) (bit-range-fixed 2 6 3) (bit-range-fixed 0 1 3))))
(define scall
  (make-instruction
   (list)
   (list (bit-range-fixed 7 11 0) (bit-range-fixed 15 19 0) (bit-range-fixed 20 31 0) (bit-range-fixed 12 14 0) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define sbreak
  (make-instruction
   (list)
   (list (bit-range-fixed 7 11 0) (bit-range-fixed 15 19 0) (bit-range-fixed 20 31 1) (bit-range-fixed 12 14 0) (bit-range-fixed 2 6 28) (bit-range-fixed 0 1 3))))
(define mv
  (make-instruction
   (list raw:rd raw:rs1)
   (list (bit-range-fixed 20 31 0) (bit-range-fixed 12 14 0) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define neg
  (make-instruction
   (list raw:rd raw:rs2)
   (list (bit-range-fixed 25 31 32) (bit-range-fixed 15 19 0) (bit-range-fixed 12 14 0) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define nop
  (make-instruction
   (list)
   (list (bit-range-fixed 20 31 0) (bit-range-fixed 15 19 0) (bit-range-fixed 12 14 0) (bit-range-fixed 7 11 0) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define zext.b
  (make-instruction
   (list raw:rd raw:rs1)
   (list (bit-range-fixed 20 31 255) (bit-range-fixed 12 14 7) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define ret
  (make-instruction
   (list)
   (list (bit-range-fixed 20 31 0) (bit-range-fixed 15 19 1) (bit-range-fixed 12 14 0) (bit-range-fixed 7 11 0) (bit-range-fixed 2 6 25) (bit-range-fixed 0 1 3))))
(define bleu
  (let ([encode (make-instruction
   (list rebuilt:bimm12 raw:rs2 raw:rs1 rebuilt:bimm12)
   (list (bit-range-fixed 12 14 7) (bit-range-fixed 2 6 24) (bit-range-fixed 0 1 3)))])
    (lambda (bimm12 rs2 rs1)
      (encode bimm12 rs2 rs1 bimm12))))
(define bgtu
  (let ([encode (make-instruction
   (list rebuilt:bimm12 raw:rs2 raw:rs1 rebuilt:bimm12)
   (list (bit-range-fixed 12 14 6) (bit-range-fixed 2 6 24) (bit-range-fixed 0 1 3)))])
    (lambda (bimm12 rs2 rs1)
      (encode bimm12 rs2 rs1 bimm12))))
(define ble
  (let ([encode (make-instruction
   (list rebuilt:bimm12 raw:rs2 raw:rs1 rebuilt:bimm12)
   (list (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 24) (bit-range-fixed 0 1 3)))])
    (lambda (bimm12 rs2 rs1)
      (encode bimm12 rs2 rs1 bimm12))))
(define bgez
  (let ([encode (make-instruction
   (list rebuilt:bimm12 raw:rs1 rebuilt:bimm12)
   (list (bit-range-fixed 20 24 0) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 24) (bit-range-fixed 0 1 3)))])
    (lambda (bimm12 rs1)
      (encode bimm12 rs1 bimm12))))
(define blez
  (let ([encode (make-instruction
   (list rebuilt:bimm12 raw:rs2 rebuilt:bimm12)
   (list (bit-range-fixed 15 19 0) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 24) (bit-range-fixed 0 1 3)))])
    (lambda (bimm12 rs2)
      (encode bimm12 rs2 bimm12))))
(define bgt
  (let ([encode (make-instruction
   (list rebuilt:bimm12 raw:rs2 raw:rs1 rebuilt:bimm12)
   (list (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 24) (bit-range-fixed 0 1 3)))])
    (lambda (bimm12 rs2 rs1)
      (encode bimm12 rs2 rs1 bimm12))))
(define bgtz
  (let ([encode (make-instruction
   (list rebuilt:bimm12 raw:rs2 rebuilt:bimm12)
   (list (bit-range-fixed 15 19 0) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 24) (bit-range-fixed 0 1 3)))])
    (lambda (bimm12 rs2)
      (encode bimm12 rs2 bimm12))))
(define bltz
  (let ([encode (make-instruction
   (list rebuilt:bimm12 raw:rs1 rebuilt:bimm12)
   (list (bit-range-fixed 20 24 0) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 24) (bit-range-fixed 0 1 3)))])
    (lambda (bimm12 rs1)
      (encode bimm12 rs1 bimm12))))
(define bnez
  (let ([encode (make-instruction
   (list rebuilt:bimm12 raw:rs1 rebuilt:bimm12)
   (list (bit-range-fixed 20 24 0) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 24) (bit-range-fixed 0 1 3)))])
    (lambda (bimm12 rs1)
      (encode bimm12 rs1 bimm12))))
(define beqz
  (let ([encode (make-instruction
   (list rebuilt:bimm12 raw:rs1 rebuilt:bimm12)
   (list (bit-range-fixed 20 24 0) (bit-range-fixed 12 14 0) (bit-range-fixed 2 6 24) (bit-range-fixed 0 1 3)))])
    (lambda (bimm12 rs1)
      (encode bimm12 rs1 bimm12))))
(define seqz
  (make-instruction
   (list raw:rd raw:rs1)
   (list (bit-range-fixed 20 31 1) (bit-range-fixed 12 14 3) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define snez
  (make-instruction
   (list raw:rd raw:rs2)
   (list (bit-range-fixed 25 31 0) (bit-range-fixed 15 19 0) (bit-range-fixed 12 14 3) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define sltz
  (make-instruction
   (list raw:rd raw:rs1)
   (list (bit-range-fixed 25 31 0) (bit-range-fixed 20 24 0) (bit-range-fixed 12 14 2) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define sgtz
  (make-instruction
   (list raw:rd raw:rs2)
   (list (bit-range-fixed 25 31 0) (bit-range-fixed 15 19 0) (bit-range-fixed 12 14 2) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define jr
  (make-instruction
   (list raw:rs1)
   (list (bit-range-fixed 20 31 0) (bit-range-fixed 12 14 0) (bit-range-fixed 7 11 0) (bit-range-fixed 2 6 25) (bit-range-fixed 0 1 3))))
(define j
  (make-instruction
   (list raw:jimm20)
   (list (bit-range-fixed 7 11 0) (bit-range-fixed 2 6 27) (bit-range-fixed 0 1 3))))

(provide
 lui
 auipc
 jal
 jalr
 beq
 bne
 blt
 bge
 bltu
 bgeu
 lb
 lh
 lw
 lbu
 lhu
 sb
 sh
 sw
 addi
 slti
 sltiu
 xori
 ori
 andi
 add
 sub
 sll
 slt
 sltu
 xor
 srl
 sra
 or
 and
 fence
 ecall
 ebreak
 fence.tso
 pause
 scall
 sbreak
 mv
 neg
 nop
 zext.b
 ret
 bleu
 bgtu
 ble
 bgez
 blez
 bgt
 bgtz
 bltz
 bnez
 beqz
 seqz
 snez
 sltz
 sgtz
 jr
 j)
