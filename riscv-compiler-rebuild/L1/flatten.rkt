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
;;; 输入/输出都是普通 list: '((label ...) (insn ...) ...)
;;; 输出里 label 的链带上完整作用域前缀, 引用改写成完整链。
;;; 链 -> id / 偏移 是布局层的事, 本层不碰。

(provide name?
         path?
         flatten-program
         flatten-inputs
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

;; 程序 = 普通 list. 旧写法 (quote ...) / (begin ...) 也收, 但出口一律是 plain list.
(define (program-items prog)
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

;; runs = 多个输入各自的 annotated; 相邻性在输入边界处重置
(define (build-table! runs)
  (define table (make-hash))
  (define slot -1)
  (for ([annotated (in-list runs)])
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
           [(= (hash-ref table full) slot) (void)]      ; 同位置重复写同一个名字: 忽略
           [else (error 'flatten "label ~s is defined in two places" full)])]
        [else (set! previous-was-label? #f)])))
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
  (define-values (rev-out _prev _here)
    (for/fold ([rev-out '()] [previous-was-label? #f] [emitted-here '()])
              ([entry (in-list annotated)])
      (define scope (car entry))
      (define it (cdr entry))
      (cond
        [(label-form? it)
         (define here (if previous-was-label? emitted-here '()))
         (define full (append scope (relative-path it)))
         (if (member full here)
             (values rev-out #t here)                  ; 同位置重复名字只写一次
             (values (cons (cons 'label full) rev-out) #t (cons full here)))]
        [else
         (values (cons (rewrite-operands it scope table) rev-out) #f emitted-here)])))
  (reverse rev-out))

;; ---------------------------------------------------------------------------
;; 入口
;; ---------------------------------------------------------------------------

;; flatten-items : 程序体 -> (values 扁平 item 列表 名字表)
(define (flatten-items items)
  (flatten-inputs (list items)))

;; flatten-inputs : (listof 输入) -> (values (listof 扁平 input) 名字表)
;;   第一个返回值与输入一一对应, 顺序不变
;; 多个输入(程序 + 数据)共享同一张名字表, 所以跨输入引用(a.b 这种完整链)能查到;
;; 每个输入各自从空作用域开始展平。
(define (flatten-inputs inputs)
  (define runs (for/list ([in (in-list inputs)]) (annotate (program-items in) '())))
  (define table (build-table! runs))
  (values (for/list ([run (in-list runs)]) (emit run table)) table))

;; flatten-program : (listof item) -> (listof item)   ; 单个输入
(define (flatten-program prog)
  (define-values (outs _) (flatten-inputs (list prog)))
  (car outs))
