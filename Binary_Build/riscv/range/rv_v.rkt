#lang racket
(require "../../base.rkt"
         "helper.rkt")

;; ============================================================
;; V 扩展字段
;; ============================================================

;; 向量寄存器 — 和标量寄存器 [11:7]/[19:15]/[24:20] 同编码位
(define vd  (make-bitfield-field (bit-range 0 4 7 11)  'vd  0 4))
(define vs1 (make-bitfield-field (bit-range 0 4 15 19) 'vs1 0 4))
(define vs2 (make-bitfield-field (bit-range 0 4 20 24) 'vs2 0 4))
(define vs3 vs2)  ; vs3 占用 rs2 位置 (store 类指令)

;; 向量掩码 bit 25
(define vm (make-bitfield-field (bit-range 0 0 25 25) 'vm 0 0))

;; 段数量 bits [31:29]
(define nf (make-bitfield-field (bit-range 0 2 29 31) 'nf 0 2))

;; 5-bit 有符号立即数 (bits [19:15]，与 rs1 同位置)
(define simm5
  (make-signed-field (bit-range 0 4 15 19) 'simm5 0 4))

;; 5-bit 无符号立即数 (bits [19:15])
(define zimm5
  (make-bitfield-field (bit-range 0 4 15 19) 'zimm5 0 4))

;; 10-bit 无符号立即数 (bits [29:20], vsetivli)
(define zimm10
  (make-bitfield-field (bit-range 0 9 20 29) 'zimm10 0 9))

;; 11-bit 无符号立即数 (bits [30:20], vsetvli)
(define zimm11
  (make-bitfield-field (bit-range 0 10 20 30) 'zimm11 0 10))

(provide vd vs1 vs2 vs3 vm nf simm5 zimm5 zimm10 zimm11)
