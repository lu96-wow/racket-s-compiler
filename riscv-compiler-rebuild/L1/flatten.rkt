#lang racket
;;; L1/flatten.rkt
;;;
;;; 模块展平 + 链式查表。只做名字, 不做指令。
;;;
;;; 名字(name) : symbol | string | number  (只要求 equal? 能比较)
;;; 链(path)   : 非空名字列表, 例如 (a g)
;;;
;;; 展平规则(module 可任意嵌套, 一层前缀一层):
;;;
;;;   (module a (label b c))           -> (label a b c)
;;;   (module a (module b (label c)))  -> (label a b c)
;;;
;;; 查表规则(链式): 引用 r 出现在作用域链 s 上时, 依次试
;;;
;;;   s++r, s[0..-2]++r, ..., r
;;;
;;; 第一个命中的赢(内层遮蔽外层); 都试不到就报错。
;;;
;;; 引用在源码里写成链: (jal x0 (g)) / (jal ra (b g))。
;;; 裸原子不当引用(寄存器、立即数都是裸原子), 所以本层不需要认识任何助记符。
;;;
;;; 一个位置可以有多个名字: 连续写多条 label 即可。
;;;
;;;   (label a f)
;;;   (label a g)      ; 同一位置, 两个链 = 两个名字
;;;
;;; 输出: quote-list; label 的链带上完整作用域前缀, 引用改写成完整链。
;;; 链 -> id / 偏移 是布局层的事, 本层不碰。

(provide name?
         path?
         flatten-program
         flatten-items)

;; ---------------------------------------------------------------------------
;; 基本形状
;; ---------------------------------------------------------------------------

(define (form? x) (and (pair? x) (list? x)))

(define (name? x)
  (or (symbol? x) (string? x) (number? x)))

(define (path? x)
  (and (list? x) (pair? x) (andmap name? x)))

(define (module-form? x) (and (form? x) (eq? (car x) 'module)))
(define (label-form? x)  (and (form? x) (eq? (car x) 'label) (path? (cdr x))))
(define (label-ish? x)   (and (form? x) (eq? (car x) 'label)))

;; (label b c) 里的 (b c) 是相对当前作用域的链
(define (relative-path x) (cdr x))

;; 程序体: 允许整体多包一层 (begin ...) 当容器
(define (quote-list? x)
  (and (form? x)
       (eq? (car x) 'quote)
       (pair? (cdr x))
       (null? (cddr x))
       (list? (cadr x))))

(define (program-parts prog)
  (define body (cond [(quote-list? prog) (cadr prog)]
                     [(list? prog) prog]
                     [else (list prog)]))
  (if (and (form? body) (eq? (car body) 'begin))
      (values (cdr body) #t)
      (values body #f)))

;; ---------------------------------------------------------------------------
;; 第 1 步: 展平模块结构, 给每个 item 标注它的作用域链
;; ---------------------------------------------------------------------------

(define (annotate items scope)
  (append*
   (for/list ([it (in-list items)])
     (cond
       [(module-form? it)
        (unless (and (>= (length it) 2) (name? (cadr it)))
          (error 'flatten "module needs a name: ~e" it))
        (annotate (cddr it) (append scope (list (cadr it))))]
       [(label-ish? it)
        (unless (label-form? it)
          (error 'flatten "label needs at least one name, and only names: ~e" it))
        (list (cons scope it))]
       [else (list (cons scope it))]))))

;; ---------------------------------------------------------------------------
;; 第 2 步: 建表 (完整链 -> 位置序号)
;;
;; 位置序号 = 第几段连续的 label 组。展平后相邻的 label 形式是同一个位置,
;; 所以连续写 (label a f) (label a g) 得到同一个序号、两个名字。
;; 同一条链出现在两个不同位置 => 报错。
;; ---------------------------------------------------------------------------

(define (build-table! annotated)
  (define table (make-hash))
  (define slot -1)
  (define previous-was-label? #f)
  (for ([entry (in-list annotated)])
    (define it (cdr entry))
    (cond
      [(label-form? it)
       (unless previous-was-label? (set! slot (add1 slot)))
       (set! previous-was-label? #t)
       (define full (append (car entry) (relative-path it)))
       (cond
         [(not (hash-has-key? table full)) (hash-set! table full slot)]
         [(= (hash-ref table full) slot) (void)]        ; 同位置重复写同一个名字: 忽略
         [else (error 'flatten "label ~s is defined in two places" full)])]
      [else (set! previous-was-label? #f)]))
  table)

;; ---------------------------------------------------------------------------
;; 第 3 步: 链式查表
;; ---------------------------------------------------------------------------

(define (resolve-path table scope ref)
  (let loop ([s scope])
    (define candidate (append s ref))
    (cond
      [(hash-has-key? table candidate) candidate]
      [(null? s) #f]
      [else (loop (drop-right s 1))])))

(define (resolve-or-error table scope ref)
  (or (resolve-path table scope ref)
      (error 'flatten "undefined label ~s (scope ~s)" ref scope)))

;; 只改写成链的 operand; 裸原子(寄存器/立即数)不动
(define (rewrite-operands item scope table)
  (cons (car item)
        (for/list ([x (in-list (cdr item))])
          (if (path? x)
              (resolve-or-error table scope x)
              x))))

;; ---------------------------------------------------------------------------
;; 第 4 步: 输出
;; ---------------------------------------------------------------------------

(define (emit annotated table)
  (define out '())
  (define previous-was-label? #f)
  (define emitted-here '())
  (for ([entry (in-list annotated)])
    (define scope (car entry))
    (define it (cdr entry))
    (cond
      [(label-form? it)
       (unless previous-was-label? (set! emitted-here '()))
       (set! previous-was-label? #t)
       (define full (append scope (relative-path it)))
       (unless (member full emitted-here)             ; 同位置重复名字只写一次
         (set! emitted-here (cons full emitted-here))
         (set! out (append out (list (cons 'label full)))))]
      [else
       (set! previous-was-label? #f)
       (set! out (append out (list (rewrite-operands it scope table))))]))
  out)

;; ---------------------------------------------------------------------------
;; 入口
;; ---------------------------------------------------------------------------

;; flatten-items : 程序体 -> (values 扁平 item 列表 名字表)
(define (flatten-items items)
  (define annotated (annotate items '()))
  (define table (build-table! annotated))
  (values (emit annotated table) table))

;; flatten-program : quote-list | (listof item) -> quote-list
(define (flatten-program prog)
  (define-values (items with-begin?) (program-parts prog))
  (define-values (flat _) (flatten-items items))
  (list 'quote (if with-begin? (cons 'begin flat) flat)))
