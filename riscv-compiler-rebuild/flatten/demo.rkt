#lang racket
;;; flatten/demo.rkt -- 模块系统 + 链式查表
;;;
;;; 输入: 多段 item（模块可以嵌套，可以分散在不同输入里）
;;; 输出: 每个 item 的链都变成**完整链**，引用改写成完整链；外加一张名字表。
;;;
;;; 这一段演示:
;;;   * module + provide/require（默认私有）
;;;   * rename-out（内部叫 (d table)，对外叫 table）
;;;   * rename-in（导入时改名）
;;;   * prefix-in（绑成 p:名字）
;;;   * 跨输入 require；require 成环（数据 <-> 代码）

(require "flatten.rkt")

(define prog                          ; 程序侧
  '((module prog
      (require (rename-in data (table tbl)))     ; 导入时改名
      (provide f)
      (label main)
      (la t0 (tbl))                              ; 用改名后的短名
      (jal x0 (helper))                          ; 本模块内部: 免前缀
      (label helper) (jalr x0 ra 0)
      (label f) (addi a0 a0 1) (jalr x0 ra 0))))

(define data                          ; 数据侧（另一个输入；和 prog 互相 require）
  '((module data
      (provide (rename-out ((d table) table)))   ; 导出时改名
      (require (prefix-in p: prog))              ; 带前缀
      (label d table)
      (b64 (label+ (p:f) 0))                     ; 引用 prog 的 f
      (utf-stringz "hi"))))

(displayln ";; 输入: 两个输入，各自有模块")
(for ([in (in-list (list prog data))])
  (for ([it (in-list in)]) (displayln (format "  ~s" it))))
(newline)

(define-values (outs names) (flatten-inputs (list prog data)))

(displayln ";; 展平后: 链全部是完整链")
(for ([in (in-list outs)])
  (for ([it (in-list in)]) (displayln (format "  ~s" it))))
(newline)

(displayln ";; 名字表 (完整链 -> 位置序号)")
(for ([k (in-list (sort (hash-keys names) string<? #:key ~a))])
  (displayln (format "  ~s -> ~a" k (hash-ref names k))))
(newline)

;; 私有性: 下面这些会被拒绝
(displayln ";; 私有 / 缺失的引用会被拒绝")
(define bad-cases
  (list '((module bad (la t0 (prog helper))))     ; helper 没 provide
        '((module bad (la t0 (prog nope))))       ; 不存在
        '((module bad (require ghost) (label x)))))
(for ([case (in-list bad-cases)])
  (with-handlers ([exn:fail? (lambda (e) (displayln (format "  ~a" (exn-message e))))])
    (flatten-inputs (list case))
    (displayln "  (没有报错?!)")))
