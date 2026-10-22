#lang racket/base

(require rackunit
         (prefix-in raw: "../../../generated/riscv/instruction/raw/rv_i.rkt")
         (prefix-in rebuilt: "../../../generated/riscv/instruction/rebuilt/rv_i.rkt"))

;; addi x1, x2, 3
(check-equal? (raw:addi 1 2 3) #x00310093)
(check-equal? (rebuilt:addi 1 2 3) #x00310093)

;; lui x1, 0x12345
(check-equal? (raw:lui 1 #x12345) #x123450B7)
(check-equal? (rebuilt:lui 1 #x12345) #x123450B7)

;; add x1, x2, x3
(check-equal? (raw:add 1 2 3) #x003100B3)
(check-equal? (rebuilt:add 1 2 3) #x003100B3)

;; sb x1, 4(x2)
;; raw:  imm12hi=4, rs1=2, rs2=1, imm12lo=4
;; rebuilt: rs1=2, rs2=1, imm12=4
(check-equal? (raw:sb 4 2 1 4) #x00110223)
(check-equal? (rebuilt:sb 4 2 1) #x00110223)

;; sw x3, 8(x4)
;; raw:  imm12hi=8, rs1=4, rs2=3, imm12lo=8
;; rebuilt: rs1=4, rs2=3, imm12=8
(check-equal? (raw:sw 8 4 3 8) #x00322423)
(check-equal? (rebuilt:sw 8 4 3) #x00322423)

;; beq x1, x2, 8
;; raw:  bimm12hi=8, rs1=1, rs2=2, bimm12lo=8
;; rebuilt: rs1=1, rs2=2, bimm12=8
(check-equal? (raw:beq 8 1 2 8) #x00208463)
(check-equal? (rebuilt:beq 8 1 2) #x00208463)

;; fence iorw, iorw, x0, x0
(check-equal? (rebuilt:fence 0 #b1111 #b1111 0 0) #x0FF0000F)

;; ecall / ebreak
(check-equal? (raw:ecall) #x00000073)
(check-equal? (rebuilt:ecall) #x00000073)
(check-equal? (raw:ebreak) #x00100073)
(check-equal? (rebuilt:ebreak) #x00100073)

(displayln "instruction tests passed")
