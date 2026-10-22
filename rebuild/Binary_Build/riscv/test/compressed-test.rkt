#lang racket/base

(require rackunit
         (prefix-in raw: "../raw/compressed.rkt")
         (prefix-in rebuilt: "../rebuilt/compressed.rkt"))

;; ------------------------------------------------------------
;; 压缩寄存器
;; ------------------------------------------------------------

(check-equal? (raw:rd_p 8) 0)
(check-equal? (raw:rd_p 15) #x1C)
(check-equal? (raw:rs1_p 8) 0)
(check-equal? (raw:rs1_p 15) #x380)
(check-equal? (raw:rd_rs1_p 9) #x80)
(check-equal? (raw:c_sreg1 15) #x380)
(check-equal? (raw:c_sreg2 15) #x1C)
(check-equal? (raw:rd_p_e 8) 0)
(check-equal? (raw:rd_p_e 14) #x18)
(check-equal? (raw:rs2_p_e 14) #x18)
(check-equal? (raw:rs2_e 30) #x1E00000)
(check-equal? (raw:rd_n0_e 30) #xF00)

(check-exn exn:fail? (lambda () (raw:rd_p 7)))
(check-exn exn:fail? (lambda () (raw:rd_p 16)))
(check-exn exn:fail? (lambda () (raw:rd_p_e 9)))

;; ------------------------------------------------------------
;; 立即数位映射
;; ------------------------------------------------------------

;; C.LW / C.SW: uimm[2] -> inst[6], uimm[6] -> inst[5]
(check-equal? (raw:c_uimm7lo 0) 0)
(check-equal? (raw:c_uimm7lo #x04) #x40)
(check-equal? (raw:c_uimm7lo #x40) #x20)
(check-equal? (raw:c_uimm7lo #x44) #x60)
(check-equal? (raw:c_uimm7hi #x18) #xC00) ; uimm[3:4] -> inst[10:11]
(check-equal? (rebuilt:c_uimm7 #x7C) #x1C60)

;; C.LD / C.SD: uimm[6:7] -> inst[5:6]
(check-equal? (raw:c_uimm8lo #x40) #x20)
(check-equal? (raw:c_uimm8lo #x80) #x40)
(check-equal? (raw:c_uimm8lo #xC0) #x60)
(check-equal? (rebuilt:c_uimm8 #xFC) #x1C60)

;; C.ADDI / C.LI: imm[4:0] -> inst[6:2], imm[5] -> inst[12]
(check-equal? (rebuilt:c_imm6 1) #x4)
(check-equal? (rebuilt:c_imm6 32) #x1000)
(check-equal? (rebuilt:c_imm6 63) #x107C)

;; C.ADDI / C.NOP: nzimm[4:0] -> inst[6:2], nzimm[5] -> inst[12]
(check-equal? (rebuilt:c_nzimm6 1) #x4)
(check-equal? (rebuilt:c_nzimm6 32) #x1000)
(check-equal? (rebuilt:c_nzimm6 63) #x107C)

;; C.ADDI16SP: nzimm[4|6|8:7|5] -> inst[6:2], nzimm[9] -> inst[12]
(check-equal? (rebuilt:c_nzimm10 16) #x40)
(check-equal? (rebuilt:c_nzimm10 64) #x20)
(check-equal? (rebuilt:c_nzimm10 128) #x8)
(check-equal? (rebuilt:c_nzimm10 256) #x10)
(check-equal? (rebuilt:c_nzimm10 512) #x1000)

;; C.LUI: nzimm[16:12] -> inst[6:2], nzimm[17] -> inst[12]
(check-equal? (rebuilt:c_nzimm18 #x1000) #x4)
(check-equal? (rebuilt:c_nzimm18 #x2000) #x8)
(check-equal? (rebuilt:c_nzimm18 #x20000) #x1000)

;; C.J: imm[11|4|9:8|10|6|7|3:1|5]
(check-equal? (raw:c_imm12 #x800) #x1000)
(check-equal? (raw:c_imm12 #x10) #x800)
(check-equal? (raw:c_imm12 #x100) #x200)
(check-equal? (raw:c_imm12 #x200) #x400)
(check-equal? (raw:c_imm12 #x400) #x100)
(check-equal? (raw:c_imm12 #x40) #x80)
(check-equal? (raw:c_imm12 #x80) #x40)
(check-equal? (raw:c_imm12 #x2) #x8)
(check-equal? (raw:c_imm12 #x4) #x10)
(check-equal? (raw:c_imm12 #x8) #x20)
(check-equal? (raw:c_imm12 #x20) #x4)

;; C.BEQZ / C.BNEZ: imm[7:6|2:1|5] -> inst[6:2], imm[8|4:3] -> inst[12:10]
(check-equal? (rebuilt:c_bimm9 #x2) #x8)
(check-equal? (rebuilt:c_bimm9 #x4) #x10)
(check-equal? (rebuilt:c_bimm9 #x6) #x18)
(check-equal? (rebuilt:c_bimm9 #x80) #x40)
(check-equal? (rebuilt:c_bimm9 #x100) #x1000)
(check-equal? (rebuilt:c_bimm9 #x1FE) #x1C7C)

;; C.SLLI / C.SRLI / C.SRAI (RV64)
(check-equal? (rebuilt:c_nzuimm6 1) #x4)
(check-equal? (rebuilt:c_nzuimm6 32) #x1000)
(check-equal? (rebuilt:c_nzuimm6 63) #x107C)

;; C.ADDI4SPN: nzuimm[5:4|9:6|2|3]
(check-equal? (raw:c_nzuimm10 #x10) #x800)
(check-equal? (raw:c_nzuimm10 #x20) #x1000)
(check-equal? (raw:c_nzuimm10 #x40) #x80)
(check-equal? (raw:c_nzuimm10 #x80) #x100)
(check-equal? (raw:c_nzuimm10 #x100) #x200)

;; C.LWSP / C.FLWSP: uimm[4:2|7:6] -> inst[6:2], uimm[5] -> inst[12]
(check-equal? (rebuilt:c_uimm8sp #x4) #x10)
(check-equal? (rebuilt:c_uimm8sp #x8) #x20)
(check-equal? (rebuilt:c_uimm8sp #x10) #x40)
(check-equal? (rebuilt:c_uimm8sp #x20) #x1000)
(check-equal? (rebuilt:c_uimm8sp #x40) #x4)
(check-equal? (rebuilt:c_uimm8sp #x80) #x8)

;; C.LDSP / C.FLDSP: uimm[4:3|8:6] -> inst[6:2], uimm[5] -> inst[12]
(check-equal? (rebuilt:c_uimm9sp #x8) #x20)
(check-equal? (rebuilt:c_uimm9sp #x10) #x40)
(check-equal? (rebuilt:c_uimm9sp #x20) #x1000)
(check-equal? (rebuilt:c_uimm9sp #x40) #x4)
(check-equal? (rebuilt:c_uimm9sp #x80) #x8)
(check-equal? (rebuilt:c_uimm9sp #x100) #x10)

;; C.SWSP / C.FSWSP: uimm[5:2|7:6] -> inst[12:7]
(check-equal? (raw:c_uimm8sp_s #x4) #x200)
(check-equal? (raw:c_uimm8sp_s #x8) #x400)
(check-equal? (raw:c_uimm8sp_s #x10) #x800)
(check-equal? (raw:c_uimm8sp_s #x20) #x1000)
(check-equal? (raw:c_uimm8sp_s #x40) #x80)
(check-equal? (raw:c_uimm8sp_s #x80) #x100)

;; C.SDSP / C.FSDSP: uimm[5:3|8:6] -> inst[12:7]
(check-equal? (raw:c_uimm9sp_s #x8) #x400)
(check-equal? (raw:c_uimm9sp_s #x10) #x800)
(check-equal? (raw:c_uimm9sp_s #x20) #x1000)
(check-equal? (raw:c_uimm9sp_s #x40) #x80)
(check-equal? (raw:c_uimm9sp_s #x80) #x100)
(check-equal? (raw:c_uimm9sp_s #x100) #x200)

;; Zcb
(check-equal? (raw:c_uimm2 1) #x20)
(check-equal? (raw:c_uimm2 2) #x40)
(check-equal? (raw:c_uimm1 1) #x20)

;; Zcmp / Zcmt / Zcmop
(check-equal? (raw:c_rlist #xF) #xF0)
(check-equal? (raw:c_spimm #b11) #b1100)
(check-equal? (raw:c_index #xAB) #x2AC)
(check-equal? (raw:c_mop_t 7) #x700)

(displayln "compressed field tests passed")
