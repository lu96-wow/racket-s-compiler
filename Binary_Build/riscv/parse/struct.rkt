#lang racket

;; ============================================================
;; 数据结构
;; ============================================================

;; 一个固定位域: bits[high..low] = value
(struct fixed-field (high low value) #:transparent)

;; 一条指令的解析结果
;;   name        : string — 助记符 (如 "addi", "fmadd.s")
;;   operands    : (listof string) — 操作数参数名 (hi/lo 已合并去重)
;;   fixed-fields: (listof fixed-field)
(struct instruction-def (name operands fixed-fields) #:transparent)

;; 一个源文件与其扩展类型符号的配对
(struct extension-source (path type-sym) #:transparent)

;; 一个扩展的全部解析结果
(struct extension-defs (source defs) #:transparent)

(provide
 fixed-field fixed-field? fixed-field-high fixed-field-low fixed-field-value
 instruction-def instruction-def? instruction-def-name
 instruction-def-operands instruction-def-fixed-fields
 extension-source extension-source? extension-source-path extension-source-type-sym
 extension-defs extension-defs? extension-defs-source extension-defs-defs)
