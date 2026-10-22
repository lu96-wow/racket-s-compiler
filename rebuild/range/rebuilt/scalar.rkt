#lang racket/base

;; ============================================================
;; 重建表示：标量扩展字段
;;
;; 通过 prefix-in 显式导入 raw 层，再定义“一个逻辑操作数对应多个
;; 原始 token”的组合字段。
;;
;; 这一层不解析字符串，也不猜测 hi/lo 关系；关系由这里的 define
;; 直接表达。
;; ============================================================

(require (prefix-in raw: "../raw/scalar.rkt")
         "../bit.rkt")

;; S 型：源码里的 imm12hi + imm12lo 组成一个有符号 12 位立即数。
;; 底层位布局与 I 型的 imm12 不同，所以这里单独组合。
(define simm12
  (combine raw:imm12hi
           raw:imm12lo))

;; B 型：源码里的 bimm12hi + bimm12lo 组成一个 13 位有符号偏移
;; （bit0 恒为 0，不参与编码）。
(define bimm12
  (combine raw:bimm12hi
           raw:bimm12lo))

(provide simm12
         bimm12)
