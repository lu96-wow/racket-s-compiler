#lang racket
;;; L1/table-base.rkt
;;;
;;; 基础整数伪指令(load / store / move / 缺的那一半分支)。
;;; 只提供 `base-rewrite-rows`, 由 table.rkt 聚合; 格式见 table.rkt 的说明。

(provide base-rewrite-rows)

;; ---------------------------------------------------------------------------
;; 替换表
;;
;;   一行 =  若干名字(全都是 symbol, 平级)
;;           + 若干规则 ((操作数模式 展开结果) ...)
;;
;; 名字没有主次: load-8 和 l8 是同级的两种写法, 谁做头都按同一组规则展开。
;; 规则里只写操作数模式, 头由实际写的那个名字带进来。
;;
;; 加一种写法  = 往名字段里再塞一个 symbol
;; 加一种形状  = 往后面再加一条规则
;; 加伪指令    = 加一行
;;
;; 本文件只有数据; 其他扩展表同名结构, 由 table.rkt append 到一起。
;;
;; 模式变量 = 以 ? 开头的符号; 同一变量重复出现须匹配 equal? 的值。
;; 其余符号/数字一律字面匹配。
;;
;; 形状约定:
;;   (load-*  d a)           ; off 省略 -> 补 0
;;   (load-*  d a off)
;;   (store-* a s)           ; off 省略 -> 补 0, 且值写最后
;;   (store-* a off s)
;;
;; load-8/16/32 是 zero-extend; load-s8/16/32 是 sign-extend。
;; ---------------------------------------------------------------------------

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

    ;; --- 存储: 统一 (地址 [偏移] 值), 值写低 bits ------------------------
    (store-8 st8
     ((?a ?s)      (sb ?s ?a 0))
     ((?a ?off ?s) (sb ?s ?a ?off)))

    (store-16 st16
     ((?a ?s)      (sh ?s ?a 0))
     ((?a ?off ?s) (sh ?s ?a ?off)))

    (store-32 st32
     ((?a ?s)      (sw ?s ?a 0))
     ((?a ?off ?s) (sw ?s ?a ?off)))

    (store-64 st64
     ((?a ?s)      (sd ?s ?a 0))
     ((?a ?off ?s) (sd ?s ?a ?off)))

    ;; --- 寄存器移动 -----------------------------------------------------
    (move mv
     ((?d ?s) (add ?d ?s x0)))

    ;; --- 分支缺的那一半: 纯换位 -----------------------------------------
    (branch-le ble
     ((?a ?b ?l) (bge ?b ?a ?l)))

    (branch-gt bgt
     ((?a ?b ?l) (blt ?b ?a ?l)))

    (branch-leu bleu
     ((?a ?b ?l) (bgeu ?b ?a ?l)))

    (branch-gtu bgtu
     ((?a ?b ?l) (bltu ?b ?a ?l)))))
