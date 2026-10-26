#lang racket
;;; L1/table.rkt
;;;
;;; L1 的全部数据: 指令头 + 各扩展的替换表拼在一起。没有逻辑。
;;; 逻辑在 rewrite.rkt: 它 require 本文件, 建索引并自检。
;;;
;;; 一个扩展一个文件, 各自 provide `xxx-rewrite-rows`, 这里 append。
;;; 加扩展只要两步, rewrite.rkt 一行都不用改:
;;;
;;;   (require "table-vector.rkt")                       ; 1. require
;;;   (define rewrite-rows (append base-rewrite-rows
;;;                                vector-rewrite-rows))  ; 2. append
;;;
;;; 行的格式(名字平级 + 操作数模式 -> 展开结果)见下面 `rewrite-rows` 的说明。
;;; 各文件之间重名 / 一行只有名字没规则等, 由 rewrite.rkt 的 make-table 报错。

(require "table-base.rkt")

(provide directive-heads
         rewrite-rows)

;; 指令头(不是助记符, 但也不能被名字占用)
;; 这里只写 L1 自己有语义的几种; 真指令名单不在本层维护。
(define directive-heads
  '(label section global bytes reserve align quote))

;; 表的顺序 = 下面 append 的顺序; 各扩展内部保持自己的书写顺序。
(define rewrite-rows
  (append base-rewrite-rows))
