#lang racket
;;; sexp.rkt
;;;
;;; 跨层共享的 s-expression 工具。**这里没有任何层语义**:
;;; 只有"什么算一个 form / 名字 / 链"和"把旧壳剥成 item 列表"。
;;;
;;; 为什么放在顶层: 这几条形状是**同一个契约**, 被 5 个层各抄过一份。
;;; 拷贝的坏处不是行数, 是分叉(有人给 name? 加一类, 别人没加)。
;;;
;;; 各层可以原样 re-provide 这里的绑定, 于是
;;;   (require "analyze/analyze.rkt" "layout/layout.rkt")
;;; 不会再因为两边都 provide as-items 而冲突 —— 它们是同一个绑定。

(provide form?
         name?
         path?
         normalize-path
         as-items
         label-expr?
         label-expr-chain
         label-expr-addend
         normalize-label-expr)

;; 真列表(代码/数据形式的形状)。'(a . b) 和 '() 都不是 form。
(define (form? x) (and (pair? x) (list? x)))

;; 名字: label 链的一节(可以是 symbol / string / number)。
(define (name? x) (or (symbol? x) (string? x) (number? x)))

;; 链: 非空名字列表, 例如 (a g)。label 与跳转目标都用它做身份。
(define (path? x) (and (list? x) (pair? x) (andmap name? x)))

;; 裸原子当单节链看: g 与 (g) 等价; 其它返回 #f。
(define (normalize-path x)
  (cond
    [(path? x) x]
    [(name? x) (list x)]
    [else #f]))

;; 地址表达式: 数据里的"符号 + 加数"。 (label+ 链) / (label+ 链 加数) / (label- 链 加数)
;; 它出现在 item 的**值**里（(value w (label+ 链 0)) 或 rich 的 (b64 (label+ 链 0))），
;; 所以判"这个操作数是不是链"是不够的 —— expand-data / flatten / layout 都靠这三个函数。
(define (label-expr? x)
  (and (form? x)
       (memq (car x) '(label+ label-))
       (let ([args (cdr x)])
         (and (memq (length args) '(1 2))
              (path? (car args))
              (or (= 1 (length args)) (exact-integer? (cadr args)))))))

(define (label-expr-chain x) (cadr x))

;; (label- 链 n) 的加数是 -n；加数省略就是 0
(define (label-expr-addend x)
  (define a (if (= 3 (length x)) (caddr x) 0))
  (if (eq? (car x) 'label-) (- a) a))

;; 归一成 (label+ 链 加数): 加数一定写出来, 下游只需认这一种形状
(define (normalize-label-expr x)
  (list 'label+ (label-expr-chain x) (label-expr-addend x)))

;; 任意输入 -> item 列表。宽容收旧壳 (quote …) / (begin …)，单条 item 也收。
;; 出口一律 plain list。
;; 名字不叫 program-items: 数据、layout 输入也走这里, 它跟"程序"无关。
(define (as-items prog)
  (define body
    (cond
      [(and (form? prog) (eq? (car prog) 'quote) (= 2 (length prog)) (list? (cadr prog)))
       (cadr prog)]
      [(list? prog) prog]
      [else (list prog)]))
  (define items
    (cond
      [(null? body) '()]
      [(pair? (car body)) body]        ; 头是 list -> item 列表
      [else (list body)]))             ; 单条 item
  (if (and (= 1 (length items)) (form? (car items)) (eq? (caar items) 'begin))
      (cdar items)
      items))
