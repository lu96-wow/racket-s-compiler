#lang racket
;;; frontend/program.rkt
;;;
;;; 前端的中间数据。只是名字解析用的记录，不进入核心 IR。
;;;
;;; 名字只有一种身份：完整全局链。
;;; 模块名、定义名、导入名都在这里用链表示。

(provide (struct-out module)
         (struct-out definition)
         (struct-out provide-spec)
         (struct-out require-spec)
         (struct-out rename)
         (struct-out unit)
         (struct-out program)
         (struct-out linked)
         resolve-local)

;; 一个模块。own-defs 保存**本地链**，顺序与源码一致。
;; 隐式根模块的名字是 '()，其 provides 是 (provide-spec #f #f) = (provide *)。
(struct module (name provides requires own-defs) #:mutable #:transparent)

;; kind : 'func | 'data | 'data-label | 'raw | 'raw-label
;; interface? : 只提供名字/kind，不进入二进制构建。
(struct definition (kind scope local global interface?) #:transparent)

;; local = #f 表示 (provide *)；否则 local/external 都是链。
(struct provide-spec (local external) #:transparent)

;; prefix = #f 或一个 symbol；renames 是 rename 的列表。
(struct require-spec (target prefix renames) #:transparent)

;; (外部链 本地链)
(struct rename (external local) #:transparent)

;; 一个顶层定义，保留源码 item 以便 rewrite 阶段输出。
(struct unit (module item global) #:transparent)

(struct program (modules defs units) #:mutable #:transparent)

;; imports : 模块链 -> (本地链 . 完整链) 列表
;; exports : 模块链 -> (外部链 . 完整链) 列表
;; all-exports : 完整链列表，已去重排序
(struct linked (program imports exports all-exports) #:transparent)

;; 在某个模块里解析一个本地链。
;;   require 绑定优先，然后是本模块直接定义的全局名。
;; 这是唯一的名字解析规则；rewrite 和 link 共用。
(define (resolve-local defs module-name imports chain)
  (define hit (assoc chain imports))
  (cond
    [hit (cdr hit)]
    [else
     (define global (append module-name chain))
     (and (hash-has-key? defs global) global)]))
