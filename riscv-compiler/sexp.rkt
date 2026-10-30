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
         arith-head?
         arith-form?
         address-expr?
         address-expr-chains
         eval-address)

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

;; 地址表达式（"值推后"）: 只有三种，就是一个很小的算术语言
;;
;;   整数                         值就是它
;;   (链)                         链的地址（裸链 = 取地址，和 (la rd (f)) 一致）
;;   (+ 表达式 表达式 ...)         求和（≥2 个操作数）
;;   (- 表达式 表达式 ...)         第一个减后面所有（≥2 个）
;;
;; 例子:
;;   (d t)                        (d t) 的地址
;;   (+ (d t) 8)                  地址 + 8
;;   (- (d t) 8)                  地址 - 8
;;   (- (d end) (d start))        两个 label 的差（长度/大小）
;;   (+ (- (d end) (d start)) 4)  差 + 4
;;
;; 求值要等 label 的地址定下来:
;;   layout/relax 只有临时位置（anchors + 段 start）;
;;   bind-labels 之后才有最终符号表（symbols）。
;; 所以求值本身放在这里，由调用方给出 resolver:
;;   measured 相传 anchor resolver，bound 相传 symbol resolver。
;; 这样“这次求值用的是临时地址还是最终地址”在调用点一眼可见。

;; 头是 + 或 - 就算"算术形式"——**先判这个**，否则 (+ 8 4) 会被当成"名字叫 + 的链"。
;; 代价: 链的首节不能是 + / -（谁也不会拿它当 label 名）。
(define (arith-head? x) (and (form? x) (memq (car x) '(+ -))))

;; 合法的算术形式: ≥2 个操作数, 每个操作数都是地址表达式
(define (arith-form? x)
  (and (arith-head? x) (>= (length x) 3) (andmap address-expr? (cdr x))))

(define (address-expr? x)
  (cond
    [(exact-integer? x) #t]
    [(arith-head? x) (arith-form? x)]
    [(path? x) #t]
    [else #f]))

;; 表达式里出现的所有链（去重，保留首次出现的顺序）
(define (address-expr-chains x)
  (remove-duplicates
   (cond
     [(exact-integer? x) '()]
     [(arith-head? x) (append* (for/list ([a (in-list (cdr x))]) (address-expr-chains a)))]
     [else (list x)])))

;; 地址表达式求值: 整数 | (链) | (+ …) | (- …)
;;
;; resolve : 链 -> 整数 | #f
;;   measured 相: anchor 的临时位置（段 start + 段内偏移）
;;   bound 相:    最终符号表里的绝对地址
;;
;; 查不到就是内部错误: 调用方应当先用地址表达式的链做完 undefined-target 检查。
(define (eval-address expr resolve)
  (cond
    [(exact-integer? expr) expr]
    [(arith-head? expr)
     (define vals (for/list ([a (in-list (cdr expr))]) (eval-address a resolve)))
     (if (eq? (car expr) '+)
         (apply + vals)
         (- (car vals) (apply + (cdr vals))))]
    [else
     (define v (resolve expr))
     (or v (error 'eval-address "undefined symbol in address expression: ~s" expr))]))

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
