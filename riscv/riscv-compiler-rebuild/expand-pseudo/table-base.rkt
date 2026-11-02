#lang racket
;;; expand-pseudo/table-base.rkt
;;;
;;; 可选的便利别名层。它已经按 riscv-opcodes native 顺序写：
;;;
;;;   - 真指令/生成器伪指令的顺序来自 instruction-info-operands
;;;   - 这里只补 riscv-opcodes 没有的便利别名
;;;   - GAS 顺序不在这里；它在 gas-syntax/ 里，是另一个可选层
;;;
;;; 默认流不包含本层。需要 load-8 / store-* / branch-le 这些别名时再加。
;;;
;;; 形状约定（native）:
;;;   (load-*  rd rs1)             ; off 省略 -> 补 0
;;;   (load-*  rd rs1 off)
;;;   (store-* off rs1 rs2)        ; 与 (sb simm12 rs1 rs2) 同序
;;;   (branch-le L rs1 rs2)        ; 目标在 native 分支的第一个操作数
;;;
;;; load-8/16/32 是 zero-extend; load-s8/16/32 是 sign-extend。

(provide base-rewrite-rows)

(define base-rewrite-rows
  '(
    ;; --- 加载: zero-extend (宽度中立) ------------------------------------
    (load-8 l8
     ((?d ?a)      (lbu ?d ?a 0))
     ((?d ?a ?off) (lbu ?d ?a ?off)))

    (load-16 l16
     ((?d ?a)      (lhu ?d ?a 0))
     ((?d ?a ?off) (lhu ?d ?a ?off)))

    (load-32 l32
     ((?d ?a)      (lwu ?d ?a 0))
     ((?d ?a ?off) (lwu ?d ?a ?off)))

    (load-64 l64
     ((?d ?a)      (ld ?d ?a 0))
     ((?d ?a ?off) (ld ?d ?a ?off)))

    ;; --- 加载: sign-extend ----------------------------------------------
    (load-s8 ls8
     ((?d ?a)      (lb ?d ?a 0))
     ((?d ?a ?off) (lb ?d ?a ?off)))

    (load-s16 ls16
     ((?d ?a)      (lh ?d ?a 0))
     ((?d ?a ?off) (lh ?d ?a ?off)))

    (load-s32 ls32
     ((?d ?a)      (lw ?d ?a 0))
     ((?d ?a ?off) (lw ?d ?a ?off)))

    ;; --- 存储: native 顺序 (偏移 基址 值) --------------------------------
    (store-8 st8
     ((?o ?a ?s)   (sb ?o ?a ?s)))

    (store-16 st16
     ((?o ?a ?s)   (sh ?o ?a ?s)))

    (store-32 st32
     ((?o ?a ?s)   (sw ?o ?a ?s)))

    (store-64 st64
     ((?o ?a ?s)   (sd ?o ?a ?s)))

    ;; --- 寄存器移动 -----------------------------------------------------
    (move mv
     ((?d ?s) (add ?d ?s x0)))

    ;; --- 缺的那一半分支: native 目标在前 --------------------------------
    (branch-le ble
     ((?l ?a ?b) (bge ?l ?b ?a)))

    (branch-gt bgt
     ((?l ?a ?b) (blt ?l ?b ?a)))

    (branch-leu bleu
     ((?l ?a ?b) (bgeu ?l ?b ?a)))

    (branch-gtu bgtu
     ((?l ?a ?b) (bltu ?l ?b ?a)))

    ;; --- 空操作 ---------------------------------------------------------
    (nop
     (() (addi x0 x0 0)))

    ;; --- 压缩空操作 -----------------------------------------------------
    ;; c.nop 的 generated info 带一个 c_nzimm6 操作数；表面仍保留无参数写法。
    (c.nop
     (() (c.addi x0 0)))))
