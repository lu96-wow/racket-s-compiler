#lang racket/base

;; ============================================================
;; 原始表示：向量扩展字段
;;
;; 名字对应 riscv-opcodes 的 V 扩展 token。
;; vs3 在 store 类指令中使用 rd 的位置 [11:7]，不是 rs2 的位置。
;; ============================================================

(require "../../base.rkt")

;; -------- 向量寄存器 --------
(define vd  (checked-field 'vd  (bit-range 0 4 7) 0 31))
(define vs1 (checked-field 'vs1 (bit-range 0 4 15) 0 31))
(define vs2 (checked-field 'vs2 (bit-range 0 4 20) 0 31))
(define vs3 (checked-field 'vs3 (bit-range 0 4 7) 0 31)) ; store 数据源

;; -------- 掩码 / 段数量 / 宽度 --------
(define vm (checked-field 'vm (bit 0 25) 0 1))
(define nf (checked-field 'nf (bit-range 0 2 29) 0 7))
(define wd (checked-field 'wd (bit 0 26) 0 1))

;; -------- 立即数 --------
;; simm5 与 scalar 的 zimm5 共用 [19:15]；zimm5 只从 scalar 导入。
(define simm5 (checked-field 'simm5 (bit-range 0 4 15) -16 15))

(define zimm10 (checked-field 'zimm10 (bit-range 0 9 20) 0 1023))
(define zimm11 (checked-field 'zimm11 (bit-range 0 10 20) 0 2047))

;; vror.vi 等使用的 6 位立即数
(define zimm6lo (checked-field 'zimm6lo (bit-range 0 4 15) 0 63))
(define zimm6hi (checked-field 'zimm6hi (bit 5 26) 0 63))

;; -------- 未批准扩展中出现的字段 --------
;; vs2x8 对应 vs2[4:3]
(define vs2x8 (checked-field 'vs2x8 (bit-range 0 1 23) 0 3))
;; ci 对应 ci[5:3]
(define ci (checked-field 'ci (bit-range 0 2 20) 0 7))
(define amoop (checked-field 'amoop (bit-range 0 4 27) 0 31))

(provide vd vs1 vs2 vs3
         vm nf wd
         simm5 zimm10 zimm11
         zimm6lo zimm6hi
         vs2x8 ci amoop)
