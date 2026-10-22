#lang racket/base

(require "../../../base.rkt"
         "../../raw/scalar.rkt"
         "../../raw/compressed.rkt"
         "../../raw/vector.rkt"
         "../../raw/mop.rkt")

(define lui
  (make-instruction
   (list rd imm20)
   (list (bit-range-fixed 2 6 13) (bit-range-fixed 0 1 3))))
(define auipc
  (make-instruction
   (list rd imm20)
   (list (bit-range-fixed 2 6 5) (bit-range-fixed 0 1 3))))
(define jal
  (make-instruction
   (list rd jimm20)
   (list (bit-range-fixed 2 6 27) (bit-range-fixed 0 1 3))))
(define jalr
  (make-instruction
   (list rd rs1 imm12)
   (list (bit-range-fixed 12 14 0) (bit-range-fixed 2 6 25) (bit-range-fixed 0 1 3))))
(define beq
  (make-instruction
   (list bimm12hi rs1 rs2 bimm12lo)
   (list (bit-range-fixed 12 14 0) (bit-range-fixed 2 6 24) (bit-range-fixed 0 1 3))))
(define bne
  (make-instruction
   (list bimm12hi rs1 rs2 bimm12lo)
   (list (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 24) (bit-range-fixed 0 1 3))))
(define blt
  (make-instruction
   (list bimm12hi rs1 rs2 bimm12lo)
   (list (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 24) (bit-range-fixed 0 1 3))))
(define bge
  (make-instruction
   (list bimm12hi rs1 rs2 bimm12lo)
   (list (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 24) (bit-range-fixed 0 1 3))))
(define bltu
  (make-instruction
   (list bimm12hi rs1 rs2 bimm12lo)
   (list (bit-range-fixed 12 14 6) (bit-range-fixed 2 6 24) (bit-range-fixed 0 1 3))))
(define bgeu
  (make-instruction
   (list bimm12hi rs1 rs2 bimm12lo)
   (list (bit-range-fixed 12 14 7) (bit-range-fixed 2 6 24) (bit-range-fixed 0 1 3))))
(define lb
  (make-instruction
   (list rd rs1 imm12)
   (list (bit-range-fixed 12 14 0) (bit-range-fixed 2 6 0) (bit-range-fixed 0 1 3))))
(define lh
  (make-instruction
   (list rd rs1 imm12)
   (list (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 0) (bit-range-fixed 0 1 3))))
(define lw
  (make-instruction
   (list rd rs1 imm12)
   (list (bit-range-fixed 12 14 2) (bit-range-fixed 2 6 0) (bit-range-fixed 0 1 3))))
(define lbu
  (make-instruction
   (list rd rs1 imm12)
   (list (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 0) (bit-range-fixed 0 1 3))))
(define lhu
  (make-instruction
   (list rd rs1 imm12)
   (list (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 0) (bit-range-fixed 0 1 3))))
(define sb
  (make-instruction
   (list imm12hi rs1 rs2 imm12lo)
   (list (bit-range-fixed 12 14 0) (bit-range-fixed 2 6 8) (bit-range-fixed 0 1 3))))
(define sh
  (make-instruction
   (list imm12hi rs1 rs2 imm12lo)
   (list (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 8) (bit-range-fixed 0 1 3))))
(define sw
  (make-instruction
   (list imm12hi rs1 rs2 imm12lo)
   (list (bit-range-fixed 12 14 2) (bit-range-fixed 2 6 8) (bit-range-fixed 0 1 3))))
(define addi
  (make-instruction
   (list rd rs1 imm12)
   (list (bit-range-fixed 12 14 0) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define slti
  (make-instruction
   (list rd rs1 imm12)
   (list (bit-range-fixed 12 14 2) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define sltiu
  (make-instruction
   (list rd rs1 imm12)
   (list (bit-range-fixed 12 14 3) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define xori
  (make-instruction
   (list rd rs1 imm12)
   (list (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define ori
  (make-instruction
   (list rd rs1 imm12)
   (list (bit-range-fixed 12 14 6) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define andi
  (make-instruction
   (list rd rs1 imm12)
   (list (bit-range-fixed 12 14 7) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define add
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 25 31 0) (bit-range-fixed 12 14 0) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define sub
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 25 31 32) (bit-range-fixed 12 14 0) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define sll
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 25 31 0) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define slt
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 25 31 0) (bit-range-fixed 12 14 2) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define sltu
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 25 31 0) (bit-range-fixed 12 14 3) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define xor
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 25 31 0) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define srl
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 25 31 0) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define sra
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 25 31 32) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define or
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 25 31 0) (bit-range-fixed 12 14 6) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define and
  (make-instruction
   (list rd rs1 rs2)
   (list (bit-range-fixed 25 31 0) (bit-range-fixed 12 14 7) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define fence
  (make-instruction
   (list fm pred succ rs1 rd)
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
   (list rs1 rd)
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
   (list rd rs1)
   (list (bit-range-fixed 20 31 0) (bit-range-fixed 12 14 0) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define neg
  (make-instruction
   (list rd rs2)
   (list (bit-range-fixed 25 31 32) (bit-range-fixed 15 19 0) (bit-range-fixed 12 14 0) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define nop
  (make-instruction
   (list)
   (list (bit-range-fixed 20 31 0) (bit-range-fixed 15 19 0) (bit-range-fixed 12 14 0) (bit-range-fixed 7 11 0) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define zext.b
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 20 31 255) (bit-range-fixed 12 14 7) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define ret
  (make-instruction
   (list)
   (list (bit-range-fixed 20 31 0) (bit-range-fixed 15 19 1) (bit-range-fixed 12 14 0) (bit-range-fixed 7 11 0) (bit-range-fixed 2 6 25) (bit-range-fixed 0 1 3))))
(define bleu
  (make-instruction
   (list bimm12hi rs2 rs1 bimm12lo)
   (list (bit-range-fixed 12 14 7) (bit-range-fixed 2 6 24) (bit-range-fixed 0 1 3))))
(define bgtu
  (make-instruction
   (list bimm12hi rs2 rs1 bimm12lo)
   (list (bit-range-fixed 12 14 6) (bit-range-fixed 2 6 24) (bit-range-fixed 0 1 3))))
(define ble
  (make-instruction
   (list bimm12hi rs2 rs1 bimm12lo)
   (list (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 24) (bit-range-fixed 0 1 3))))
(define bgez
  (make-instruction
   (list bimm12hi rs1 bimm12lo)
   (list (bit-range-fixed 20 24 0) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 24) (bit-range-fixed 0 1 3))))
(define blez
  (make-instruction
   (list bimm12hi rs2 bimm12lo)
   (list (bit-range-fixed 15 19 0) (bit-range-fixed 12 14 5) (bit-range-fixed 2 6 24) (bit-range-fixed 0 1 3))))
(define bgt
  (make-instruction
   (list bimm12hi rs2 rs1 bimm12lo)
   (list (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 24) (bit-range-fixed 0 1 3))))
(define bgtz
  (make-instruction
   (list bimm12hi rs2 bimm12lo)
   (list (bit-range-fixed 15 19 0) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 24) (bit-range-fixed 0 1 3))))
(define bltz
  (make-instruction
   (list bimm12hi rs1 bimm12lo)
   (list (bit-range-fixed 20 24 0) (bit-range-fixed 12 14 4) (bit-range-fixed 2 6 24) (bit-range-fixed 0 1 3))))
(define bnez
  (make-instruction
   (list bimm12hi rs1 bimm12lo)
   (list (bit-range-fixed 20 24 0) (bit-range-fixed 12 14 1) (bit-range-fixed 2 6 24) (bit-range-fixed 0 1 3))))
(define beqz
  (make-instruction
   (list bimm12hi rs1 bimm12lo)
   (list (bit-range-fixed 20 24 0) (bit-range-fixed 12 14 0) (bit-range-fixed 2 6 24) (bit-range-fixed 0 1 3))))
(define seqz
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 20 31 1) (bit-range-fixed 12 14 3) (bit-range-fixed 2 6 4) (bit-range-fixed 0 1 3))))
(define snez
  (make-instruction
   (list rd rs2)
   (list (bit-range-fixed 25 31 0) (bit-range-fixed 15 19 0) (bit-range-fixed 12 14 3) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define sltz
  (make-instruction
   (list rd rs1)
   (list (bit-range-fixed 25 31 0) (bit-range-fixed 20 24 0) (bit-range-fixed 12 14 2) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define sgtz
  (make-instruction
   (list rd rs2)
   (list (bit-range-fixed 25 31 0) (bit-range-fixed 15 19 0) (bit-range-fixed 12 14 2) (bit-range-fixed 2 6 12) (bit-range-fixed 0 1 3))))
(define jr
  (make-instruction
   (list rs1)
   (list (bit-range-fixed 20 31 0) (bit-range-fixed 12 14 0) (bit-range-fixed 7 11 0) (bit-range-fixed 2 6 25) (bit-range-fixed 0 1 3))))
(define j
  (make-instruction
   (list jimm20)
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
