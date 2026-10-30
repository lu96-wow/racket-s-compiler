#lang racket/base

;; ============================================================
;; 原始表示：标量扩展字段
;;
;; 这里的名字严格对应 riscv-opcodes 源文件里的 token。
;; 不做 hi/lo 合并，也不做语义重命名。
;;
;; 每个字段函数都接收“完整逻辑值”，在编码前检查范围/对齐。
;; hi/lo 分片共享同一个完整逻辑范围：
;;   imm12hi / imm12lo 都检查 signed 12-bit
;;   bimm12hi / bimm12lo 都检查 signed 13-bit, align 2
;; ============================================================

(require "../../base.rkt")

;; -------- 通用寄存器 --------
(define rd  (checked-field 'rd  (bit-range 0 4 7) 0 31))
(define rt  (checked-field 'rt  (bit-range 0 4 15) 0 31))
(define rs1 (checked-field 'rs1 (bit-range 0 4 15) 0 31))
(define rs2 (checked-field 'rs2 (bit-range 0 4 20) 0 31))
(define rs3 (checked-field 'rs3 (bit-range 0 4 27) 0 31))

;; -------- 原子/内存序 --------
(define aqrl (checked-field 'aqrl (bit-range 0 1 25) 0 3))
(define aq   (checked-field 'aq   (bit 0 26) 0 1))
(define rl   (checked-field 'rl   (bit 0 25) 0 1))

;; -------- fence --------
(define fm   (checked-field 'fm   (bit-range 0 3 28) 0 15))
(define pred (checked-field 'pred (bit-range 0 3 24) 0 15))
(define succ (checked-field 'succ (bit-range 0 3 20) 0 15))

;; -------- 浮点舍入模式 --------
(define rm (checked-field 'rm (bit-range 0 2 12) 0 7))

;; -------- U / J / I / S / B 型 --------
(define imm20 (checked-field 'imm20 (bit-range 0 19 12) 0 #xFFFFF))

(define jimm20
  (checked-field
   'jimm20
   (combine (bit-range 1 10 21)
            (bit-range 11 11 20)
            (bit-range 12 19 12)
            (bit-range 20 20 31))
   -1048576 1048574 2))

(define imm12 (checked-field 'imm12 (bit-range 0 11 20) -2048 2047))
(define csr   (checked-field 'csr   (bit-range 0 11 20) 0 #xFFF))

(define imm12hi (checked-field 'imm12hi (bit-range 5 11 25) -2048 2047))
(define imm12lo (checked-field 'imm12lo (bit-range 0 4 7) -2048 2047))

(define bimm12hi
  (checked-field
   'bimm12hi
   (combine (bit-range 5 10 25)
            (bit-range 12 12 31))
   -4096 4094 2))

(define bimm12lo
  (checked-field
   'bimm12lo
   (combine (bit-range 1 4 8)
            (bit-range 11 11 7))
   -4096 4094 2))

;; -------- 移位量 --------
(define shamtq  (checked-field 'shamtq  (bit-range 0 6 20) 0 127))
(define shamtw  (checked-field 'shamtw  (bit-range 0 4 20) 0 31))
(define shamtw4 (checked-field 'shamtw4 (bit-range 0 3 20) 0 15))
(define shamtd  (checked-field 'shamtd  (bit-range 0 5 20) 0 63))

;; -------- 小型立即数 --------
(define bs   (checked-field 'bs   (bit-range 0 1 30) 0 3))
(define rnum (checked-field 'rnum (bit-range 0 3 20) 0 15))
(define rc   (checked-field 'rc   (bit-range 0 4 25) 0 31))

(define imm2 (checked-field 'imm2 (bit-range 0 1 20) 0 3))
(define imm3 (checked-field 'imm3 (bit-range 0 2 20) 0 7))
(define imm4 (checked-field 'imm4 (bit-range 0 3 20) 0 15))
(define imm5 (checked-field 'imm5 (bit-range 0 4 20) 0 31))
(define imm6 (checked-field 'imm6 (bit-range 0 5 20) 0 63))

(define zimm5 (checked-field 'zimm5 (bit-range 0 4 15) 0 31))

(provide
 rd rt rs1 rs2 rs3
 aqrl aq rl
 fm pred succ
 rm
 imm20 jimm20 imm12 csr
 imm12hi imm12lo
 bimm12hi bimm12lo
 shamtq shamtw shamtw4 shamtd
 bs rnum rc
 imm2 imm3 imm4 imm5 imm6
 zimm5)
