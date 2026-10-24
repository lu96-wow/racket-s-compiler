#lang racket/base

;; ============================================================
;; 原始表示：压缩指令字段
;;
;; 名字严格对应 riscv-opcodes 的 C 扩展 token。
;; 每个函数接收“完整逻辑值”，只负责产出自己的位模式。
;;
;; C 扩展的立即数经常不连续，这里用 bit-map 显式列出每个逻辑位
;; 到指令位的映射，不做任何字符串/后缀推断。
;; ============================================================

(require "../../base.rkt")

;; ------------------------------------------------------------
;; 寄存器字段
;;
;; rd_p / rs1_p / rs2_p / c_sreg1 / c_sreg2 的编码值是
;; 寄存器号减去 8；这里让 raw 函数直接接收 a0-a5 / s0-s1
;; 这类完整寄存器号，而不是 0..7。
;; ------------------------------------------------------------

(define (biased-register-field dst-lo base width)
  (define encode (bit-range 0 (sub1 width) dst-lo))
  (define limit (arithmetic-shift 1 width))
  (lambda (value)
    (unless (exact-integer? value)
      (raise-argument-error 'compressed-register "exact-integer?" value))
    (unless (<= base value (+ base (sub1 limit)))
      (error 'compressed-register
             "register number ~a out of range [~a, ~a]"
             value base (+ base (sub1 limit))))
    (encode (- value base))))

(define (biased-scaled-register-field dst-lo base width scale)
  (define encode (bit-range 0 (sub1 width) dst-lo))
  (define limit (arithmetic-shift 1 width))
  (lambda (value)
    (unless (exact-integer? value)
      (raise-argument-error 'compressed-register "exact-integer?" value))
    (define offset (- value base))
    (unless (and (>= offset 0)
                 (< (quotient offset scale) limit)
                 (zero? (modulo offset scale)))
      (error 'compressed-register
             "register number ~a is not a valid ~a-aligned register in this field"
             value scale))
    (encode (quotient offset scale))))

;; compressed registers x8-x15
(define rd_p      (biased-register-field 2 8 3))
(define rs1_p     (biased-register-field 7 8 3))
(define rs2_p     (biased-register-field 2 8 3))
(define rd_rs1_p  (biased-register-field 7 8 3))
(define c_sreg1   (biased-register-field 7 8 3))
(define c_sreg2   (biased-register-field 2 8 3))

;; even compressed registers
(define rd_p_e  (biased-scaled-register-field 3 8 2 2))
(define rs2_p_e (biased-scaled-register-field 3 8 2 2))

;; normal 5-bit register fields
(define rd_rs1_n0
  (checked-field 'rd_rs1_n0
                 (bit-range 0 4 7)
                 0 31 1))
(define rd_rs1
  (checked-field 'rd_rs1
                 (bit-range 0 4 7)
                 0 31 1))
(define rd_n0
  (checked-field 'rd_n0
                 (bit-range 0 4 7)
                 0 31 1))
(define rd_n2
  (checked-field 'rd_n2
                 (bit-range 0 4 7)
                 0 31 1))
(define rs1_n0
  (checked-field 'rs1_n0
                 (bit-range 0 4 7)
                 0 31 1))
(define c_rs1_n0
  (checked-field 'c_rs1_n0
                 (bit-range 0 4 7)
                 0 31 1))
(define c_rs2
  (checked-field 'c_rs2
                 (bit-range 0 4 2)
                 0 31 1))
(define c_rs2_n0
  (checked-field 'c_rs2_n0
                 (bit-range 0 4 2)
                 0 31 1))

;; even normal registers
(define rd_n0_e (biased-scaled-register-field 8 0 4 2))
(define rd_e    (biased-scaled-register-field 8 0 4 2))
(define c_rs2_e (biased-scaled-register-field 3 0 4 2))
(define rs2_e   (biased-scaled-register-field 21 0 4 2))

;; ------------------------------------------------------------
;; 立即数片段
;; ------------------------------------------------------------

;; C.ADDI4SPN nzuimm[5:4|9:6|2|3]
(define c_nzuimm10
  (checked-field 'c_nzuimm10
                 (bit-map '(5 . 12)
           '(4 . 11)
           '(9 . 10)
           '(8 . 9)
           '(7 . 8)
           '(6 . 7)
           '(2 . 6)
           '(3 . 5))
                 4 1020 4))

;; C.LW / C.SW uimm[2|6] 和 uimm[5:3]
(define c_uimm7lo
  (checked-field 'c_uimm7lo
                 (bit-map '(2 . 6)
           '(6 . 5))
                 0 124 4))

(define c_uimm7hi
  (checked-field 'c_uimm7hi
                 (bit-range 3 5 10)
                 0 124 4))

;; C.LD / C.SD uimm[7:6] 和 uimm[5:3]
(define c_uimm8lo
  (checked-field 'c_uimm8lo
                 (bit-range 6 7 5)
                 0 248 8))

(define c_uimm8hi
  (checked-field 'c_uimm8hi
                 (bit-range 3 5 10)
                 0 248 8))

;; C.LDSP / C.SDSP 等 uimm[7:6] 和 uimm[5:4|8]
(define c_uimm9lo
  (checked-field 'c_uimm9lo
                 (bit-range 6 7 5)
                 0 511 1))

(define c_uimm9hi
  (checked-field 'c_uimm9hi
                 (bit-map '(5 . 12)
           '(4 . 11)
           '(8 . 10))
                 0 511 1))

;; C.ADDI / C.LI 的 imm[4:0] / imm[5]
(define c_imm6lo
  (checked-field 'c_imm6lo
                 (bit-range 0 4 2)
                 -32 31 1))

(define c_imm6hi
  (checked-field 'c_imm6hi
                 (bit 5 12)
                 -32 31 1))

;; C.ADDI / C.NOP / C.LUI 的 nzimm
(define c_nzimm6lo
  (checked-field 'c_nzimm6lo
                 (bit-range 0 4 2)
                 -32 31 1))

(define c_nzimm6hi
  (checked-field 'c_nzimm6hi
                 (bit 5 12)
                 -32 31 1))

;; C.ADDI16SP: nzimm[4|6|8:7|5] / nzimm[9]
(define c_nzimm10lo
  (checked-field 'c_nzimm10lo
                 (bit-map '(4 . 6)
           '(6 . 5)
           '(8 . 4)
           '(7 . 3)
           '(5 . 2))
                 -512 496 16))

(define c_nzimm10hi
  (checked-field 'c_nzimm10hi
                 (bit 9 12)
                 -512 496 16))

;; C.LUI: nzimm[16:12] / nzimm[17]
(define c_nzimm18lo
  (checked-field 'c_nzimm18lo
                 (bit-range 12 16 2)
                 -131072 126976 4096))

(define c_nzimm18hi
  (checked-field 'c_nzimm18hi
                 (bit 17 12)
                 -131072 126976 4096))

;; C.J: imm[11|4|9:8|10|6|7|3:1|5]
(define c_imm12
  (checked-field 'c_imm12
                 (bit-map '(11 . 12)
           '(4 . 11)
           '(9 . 10)
           '(8 . 9)
           '(10 . 8)
           '(6 . 7)
           '(7 . 6)
           '(3 . 5)
           '(2 . 4)
           '(1 . 3)
           '(5 . 2))
                 -2048 2046 2))

;; C.BEQZ / C.BNEZ: imm[7:6|2:1|5] / imm[8|4:3]
(define c_bimm9lo
  (checked-field 'c_bimm9lo
                 (bit-map '(7 . 6)
           '(6 . 5)
           '(2 . 4)
           '(1 . 3)
           '(5 . 2))
                 -256 254 2))

(define c_bimm9hi
  (checked-field 'c_bimm9hi
                 (bit-map '(8 . 12)
           '(4 . 11)
           '(3 . 10))
                 -256 254 2))

;; C.SRLI / C.SRAI (RV32): shamt[4:0]
(define c_nzuimm5
  (checked-field 'c_nzuimm5
                 (bit-range 0 4 2)
                 0 31 1))

;; C.SLLI / C.SRLI / C.SRAI (RV64): shamt[4:0] / shamt[5]
(define c_nzuimm6lo
  (checked-field 'c_nzuimm6lo
                 (bit-range 0 4 2)
                 0 63 1))

(define c_nzuimm6hi
  (checked-field 'c_nzuimm6hi
                 (bit 5 12)
                 0 63 1))

;; C.LWSP / C.FLWSP: uimm[4:2|7:6] / uimm[5]
(define c_uimm8splo
  (checked-field 'c_uimm8splo
                 (bit-map '(4 . 6)
           '(3 . 5)
           '(2 . 4)
           '(7 . 3)
           '(6 . 2))
                 0 255 4))

(define c_uimm8sphi
  (checked-field 'c_uimm8sphi
                 (bit 5 12)
                 0 255 4))

;; C.SWSP / C.FSWSP: uimm[5:2|7:6]
(define c_uimm8sp_s
  (checked-field 'c_uimm8sp_s
                 (bit-map '(5 . 12)
           '(4 . 11)
           '(3 . 10)
           '(2 . 9)
           '(7 . 8)
           '(6 . 7))
                 0 255 4))

;; C.LDSP / C.FLDSP: uimm[4:3|8:6] / uimm[5]
(define c_uimm9splo
  (checked-field 'c_uimm9splo
                 (bit-map '(4 . 6)
           '(3 . 5)
           '(8 . 4)
           '(7 . 3)
           '(6 . 2))
                 0 511 8))

(define c_uimm9sphi
  (checked-field 'c_uimm9sphi
                 (bit 5 12)
                 0 511 8))

;; C.SDSP / C.FSDSP: uimm[5:3|8:6]
(define c_uimm9sp_s
  (checked-field 'c_uimm9sp_s
                 (bit-map '(5 . 12)
           '(4 . 11)
           '(3 . 10)
           '(8 . 9)
           '(7 . 8)
           '(6 . 7))
                 0 511 8))

;; 未在当前已批准扩展中使用，但 arg_lut 中存在
(define c_uimm10splo
  (checked-field 'c_uimm10splo
                 (bit-map '(4 . 6)
           '(9 . 5)
           '(8 . 4)
           '(7 . 3)
           '(6 . 2))
                 0 1023 4))

(define c_uimm10sphi
  (checked-field 'c_uimm10sphi
                 (bit 5 12)
                 0 1023 4))

(define c_uimm10sp_s
  (checked-field 'c_uimm10sp_s
                 (bit-map '(5 . 12)
           '(4 . 11)
           '(9 . 10)
           '(8 . 9)
           '(7 . 8)
           '(6 . 7))
                 0 1023 4))

;; Zcb: uimm[1:0] / uimm[0]
(define c_uimm2
  (checked-field 'c_uimm2
                 (bit-map '(1 . 6)
           '(0 . 5))
                 0 3 1))

(define c_uimm1
  (checked-field 'c_uimm1
                 (bit 0 5)
                 0 1 1))

;; ------------------------------------------------------------
;; Zcmp / Zcmt / Zcmop 字段
;; ------------------------------------------------------------

(define c_rlist
  (checked-field 'c_rlist
                 (bit-range 0 3 4)
                 0 15 1))
(define c_spimm
  (checked-field 'c_spimm
                 (bit-range 0 1 2)
                 0 3 1))
(define c_index
  (checked-field 'c_index
                 (bit-range 0 7 2)
                 0 255 1))
(define c_mop_t
  (checked-field 'c_mop_t
                 (bit-range 0 2 8)
                 0 7 1))

(provide
 ;; compressed registers
 rd_p rs1_p rs2_p rd_rs1_p c_sreg1 c_sreg2
 rd_p_e rs2_p_e
 rd_rs1_n0 rd_rs1 rd_n0 rd_n2 rs1_n0 c_rs1_n0 c_rs2 c_rs2_n0
 rd_n0_e rd_e c_rs2_e rs2_e

 ;; immediates
 c_nzuimm10
 c_uimm7lo c_uimm7hi
 c_uimm8lo c_uimm8hi
 c_uimm9lo c_uimm9hi
 c_imm6lo c_imm6hi
 c_nzimm6lo c_nzimm6hi
 c_nzimm10lo c_nzimm10hi
 c_nzimm18lo c_nzimm18hi
 c_imm12
 c_bimm9lo c_bimm9hi
 c_nzuimm5 c_nzuimm6lo c_nzuimm6hi
 c_uimm8splo c_uimm8sphi c_uimm8sp_s
 c_uimm9splo c_uimm9sphi c_uimm9sp_s
 c_uimm10splo c_uimm10sphi c_uimm10sp_s
 c_uimm2 c_uimm1

 ;; Zcmp / Zcmt / Zcmop
 c_rlist c_spimm c_index c_mop_t)
