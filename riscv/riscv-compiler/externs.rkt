#lang racket/base

;;; externs.rkt —— 输入侧的 link 表（外部符号）
;;;
;;; 形状和产物里那张表**完全一样**，所以上一份编译写出来的 link 文件可以直接
;;; 当这一份的输入：
;;;
;;;   (link (base B) (symbol 链 地址) …)
;;;
;;; 输入额外允许地址未知：
;;;
;;;   (symbol 链 #f)      ; “这个名字存在，地址留给链接/重定位层”
;;;
;;; 可以给多份（多个模块），也可以直接给一份：
;;;
;;;   ((link …) (link …))  /  (link …)  /  '()
;;;
;;; `base` 是那份镜像的链接基址，**不参与距离计算**：地址是绝对的，距离就是
;;; 两个绝对地址相减。base 的意义在“整体搬迁”（所有地址加 Δ）时给人看的锚，
;;; 现在只解析、不校验（详见 layout/DESIGN.md 的“外部符号”一节）。
;;;
;;; 地址未知的条目现在**编不出来**：没有 reloc 层，layout 会报
;;; (unlinked-external 链)。这是故意的 —— 宁可拒绝，也不产出一个
;;; “看着能跑”的镜像。

(require "sexp.rkt")

(provide parse-externs
         extern-rows
         extern-bases
         extern-names
         extern-link-tables)

;; ---------------------------------------------------------------------------
;; 形状
;; ---------------------------------------------------------------------------

(define (link-form? x)
  (and (form? x) (eq? (car x) 'link)))

(define (base-form? x)
  (and (form? x) (eq? (car x) 'base) (= 2 (length x))))

(define (symbol-form? x)
  (and (form? x) (eq? (car x) 'symbol) (= 3 (length x))
       (path? (cadr x))))

;; 一份表: (link (base B) (symbol 链 地址|#f) …)
;;   base 可省(缺省 0); 顺序: base 在前, 其余是 symbol 行。
(define (parse-link-table x)
  (unless (link-form? x)
    (error 'externs "不是 link 表: ~e" x))
  (define body (cdr x))
  (define-values (base rest)
    (cond
      [(and (pair? body) (base-form? (car body)))
       (values (cadr (car body)) (cdr body))]
      [else (values 0 body)]))
  (unless (and (exact-integer? base) (>= base 0))
    (error 'externs "base 必须是非负整数: ~e" base))
  (for ([row (in-list rest)])
    (unless (symbol-form? row)
      (error 'externs "link 表里只接受 (symbol 链 地址) 或 (symbol 链 #f): ~e" row))
    (define addr (caddr row))
    (unless (or (not addr) (and (exact-integer? addr) (>= addr 0)))
      (error 'externs "外部符号地址必须是非负整数或 #f: ~e" row)))
  (values base rest))

;; 把 externs 输入整成一个列表: 允许 一份 / 多份 / 空
(define (extern-tables datum)
  (cond
    [(null? datum) '()]
    [(link-form? datum) (list datum)]
    [(and (list? datum) (andmap link-form? datum)) datum]
    [else (error 'externs "externs 只接受 (link …) 或其列表: ~e" datum)]))

;; ---------------------------------------------------------------------------
;; 查询
;; ---------------------------------------------------------------------------

;; (values 行表 基址表)。行表 = ((symbol 链 地址|#f) …)，按给的顺序。
(define (parse-externs datum)
  (define tables (extern-tables datum))
  (define-values (bases rows)
    (for/fold ([bases '()] [rows '()]) ([t (in-list tables)])
      (define-values (b rs) (parse-link-table t))
      (values (cons b bases) (append rows rs))))
  (values (reverse bases) rows))

(define (extern-rows datum)
  (let-values ([(bases rows) (parse-externs datum)]) rows))

(define (extern-bases datum)
  (let-values ([(bases rows) (parse-externs datum)]) bases))

;; 每份 link 表保留自己的 base: (listof (cons base rows))
(define (extern-link-tables datum)
  (for/list ([t (in-list (extern-tables datum))])
    (define-values (b rows) (parse-link-table t))
    (cons b rows)))

;; 外部符号的名字(链)，不管地址知不知道 —— flatten 只要名字。
(define (extern-names datum)
  (map cadr (extern-rows datum)))
