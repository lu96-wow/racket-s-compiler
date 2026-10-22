#lang racket/base

;; ============================================================
;; 原始表示：向量扩展字段
;;
;; 名字对应 riscv-opcodes 的 V 扩展 token。
;; vs3 在 store 类指令中使用 rd 的位置 [11:7]，不是 rs2 的位置。
;; ============================================================

(require "../../base.rkt")

;; -------- 向量寄存器 --------
(define vd  (bit-range 0 4 7))
(define vs1 (bit-range 0 4 15))
(define vs2 (bit-range 0 4 20))
(define vs3 (bit-range 0 4 7)) ; store 数据源

;; -------- 掩码 / 段数量 / 宽度 --------
(define vm (bit 0 25))
(define nf (bit-range 0 2 29))
(define wd (bit 0 26))

;; -------- 立即数 --------
;; simm5 与 scalar 的 zimm5 共用 [19:15]；zimm5 只从 scalar 导入。
(define simm5 (bit-range 0 4 15))

(define zimm10 (bit-range 0 9 20))
(define zimm11 (bit-range 0 10 20))

;; vror.vi 等使用的 6 位立即数
(define zimm6lo (bit-range 0 4 15))
(define zimm6hi (bit 5 26))

;; -------- 未批准扩展中出现的字段 --------
;; vs2x8 对应 vs2[4:3]
(define vs2x8 (bit-range 0 1 23))
;; ci 对应 ci[5:3]
(define ci (bit-range 0 2 20))
(define amoop (bit-range 0 4 27))

(provide vd vs1 vs2 vs3
         vm nf wd
         simm5 zimm10 zimm11
         zimm6lo zimm6hi
         vs2x8 ci amoop)
