#lang racket/base

;; ============================================================
;; 测试用字段范围表
;;
;; key   : rebuilt / raw operand name
;; value : (list min max align)
;;
;; 这份表是测试数据，用于生成合法值和越界值。
;; ============================================================

(define (r min max [align 1]) (list min max align))

(define field-ranges
  (hash
   ;; scalar registers / flags
   'rd (r 0 31) 'rt (r 0 31) 'rs1 (r 0 31) 'rs2 (r 0 31) 'rs3 (r 0 31)
   'aqrl (r 0 3) 'aq (r 0 1) 'rl (r 0 1)
   'fm (r 0 15) 'pred (r 0 15) 'succ (r 0 15) 'rm (r 0 7)
   'imm20 (r 0 1048575) 'jimm20 (r -1048576 1048574 2)
   'imm12 (r -2048 2047) 'csr (r 0 4095)
   'imm12hi (r -2048 2047) 'imm12lo (r -2048 2047)
   'bimm12hi (r -4096 4094 2) 'bimm12lo (r -4096 4094 2)
   'shamtq (r 0 127) 'shamtw (r 0 31) 'shamtw4 (r 0 15) 'shamtd (r 0 63)
   'bs (r 0 3) 'rnum (r 0 15) 'rc (r 0 31)
   'imm2 (r 0 3) 'imm3 (r 0 7) 'imm4 (r 0 15) 'imm5 (r 0 31) 'imm6 (r 0 63)
   'zimm5 (r 0 31)

   ;; rebuilt scalar
   'simm12 (r -2048 2047)
   'bimm12 (r -4096 4094 2)

   ;; compressed registers
   'rd_p (r 8 15) 'rs1_p (r 8 15) 'rs2_p (r 8 15) 'rd_rs1_p (r 8 15)
   'c_sreg1 (r 8 15) 'c_sreg2 (r 8 15)
   'rd_p_e (r 8 14 2) 'rs2_p_e (r 8 14 2)
   'rd_rs1_n0 (r 0 31) 'rd_rs1 (r 0 31) 'rd_n0 (r 0 31) 'rd_n2 (r 0 31)
   'rs1_n0 (r 0 31) 'c_rs1_n0 (r 0 31) 'c_rs2 (r 0 31) 'c_rs2_n0 (r 0 31)
   'rd_n0_e (r 0 30 2) 'rd_e (r 0 30 2) 'c_rs2_e (r 0 30 2) 'rs2_e (r 0 30 2)

   ;; compressed immediate fragments
   'c_nzuimm10 (r 4 1020 4)
   'c_uimm7lo (r 0 124 4) 'c_uimm7hi (r 0 124 4)
   'c_uimm8lo (r 0 248 8) 'c_uimm8hi (r 0 248 8)
   'c_uimm9lo (r 0 511) 'c_uimm9hi (r 0 511)
   'c_imm6lo (r -32 31) 'c_imm6hi (r -32 31)
   'c_nzimm6lo (r -32 31) 'c_nzimm6hi (r -32 31)
   'c_nzimm10lo (r -512 496 16) 'c_nzimm10hi (r -512 496 16)
   'c_nzimm18lo (r -131072 126976 4096) 'c_nzimm18hi (r -131072 126976 4096)
   'c_imm12 (r -2048 2046 2)
   'c_bimm9lo (r -256 254 2) 'c_bimm9hi (r -256 254 2)
   'c_nzuimm5 (r 0 31) 'c_nzuimm6lo (r 0 63) 'c_nzuimm6hi (r 0 63)
   'c_uimm8splo (r 0 255 4) 'c_uimm8sphi (r 0 255 4) 'c_uimm8sp_s (r 0 255 4)
   'c_uimm9splo (r 0 511 8) 'c_uimm9sphi (r 0 511 8) 'c_uimm9sp_s (r 0 511 8)
   'c_uimm10splo (r 0 1023 4) 'c_uimm10sphi (r 0 1023 4) 'c_uimm10sp_s (r 0 1023 4)
   'c_uimm2 (r 0 3) 'c_uimm1 (r 0 1)
   'c_rlist (r 0 15) 'c_spimm (r 0 3) 'c_index (r 0 255) 'c_mop_t (r 0 7)

   ;; rebuilt compressed
   'c_uimm7 (r 0 124 4)
   'c_uimm8 (r 0 248 8)
   'c_uimm9 (r 0 511)
   'c_imm6 (r -32 31)
   'c_nzimm6 (r -32 31)
   'c_nzimm10 (r -512 496 16)
   'c_nzimm18 (r -131072 126976 4096)
   'c_bimm9 (r -256 254 2)
   'c_nzuimm6 (r 0 63)
   'c_uimm8sp (r 0 255 4)
   'c_uimm9sp (r 0 511 8)
   'c_uimm10sp (r 0 1023 4)

   ;; vector
   'vd (r 0 31) 'vs1 (r 0 31) 'vs2 (r 0 31) 'vs3 (r 0 31)
   'vm (r 0 1) 'nf (r 0 7) 'wd (r 0 1)
   'simm5 (r -16 15) 'zimm10 (r 0 1023) 'zimm11 (r 0 2047)
   'zimm6lo (r 0 63) 'zimm6hi (r 0 63) 'zimm6 (r 0 63)
   'vs2x8 (r 0 3) 'ci (r 0 7) 'amoop (r 0 31)

   ;; Zimop
   'mop_r_t_30 (r 0 31) 'mop_r_t_27_26 (r 0 31) 'mop_r_t_21_20 (r 0 31)
   'mop_rr_t_30 (r 0 31) 'mop_rr_t_27_26 (r 0 31)
   'mop_r_t (r 0 31) 'mop_rr_t (r 0 31)))

(provide field-ranges)
