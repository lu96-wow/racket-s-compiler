#lang racket
;;; flatten/flatten.rkt
;;;
;;; 模块系统 + 链式查表。只做名字, 不做指令。
;;;
;;; 名字(name) : symbol | string | number  (只要求 equal? 能比较)
;;; 链(path)   : 非空名字列表, 例如 (a g)
;;;
;;; ---------------------------------------------------------------------------
;;; 模块
;;; ---------------------------------------------------------------------------
;;;
;;;   (module 名
;;;     (provide 链 ...                        ; 导出, 外部名 = 本地名
;;;              (rename-out (本地链 外部链) ...)  ; 导出时改名
;;;              *)                            ; 本模块直接定义的 label, 用它们的本地链
;;;     (require 模块链                          ; 拉进本模块作用域
;;;              (prefix-in p: 模块链)            ; 绑成 p:名字
;;;              (rename-in 模块链 (外部链 本地链) ...))  ; 导入时改名
;;;     item ...)
;;;
;;; 规则:
;;;   * **默认私有**: 没有 provide 的 label, 模块外引用不到。
;;;   * label 在**声明它的模块及其子模块**里可见, 内层遮蔽外层(词法嵌套)。
;;;   * require 绑定在**本模块及其子模块**里可见(同样由内到外)。
;;;   * 解析顺序: require 绑定(由内到外) -> 本地 label(由内到外)。
;;;   * 同名冲突(两个 require / require 与本模块 label) -> 报错。
;;;   * 循环 require **允许**(只是名字解析, 没有初始化顺序)；环里要有 base 才解得出来。
;;;   * 可以 re-export: provide 的名字可以是 require 进来的。
;;;
;;; 一个位置可以有多个名字: 连续写多条 label 即可。
;;;
;;;   (label a f)
;;;   (label a g)      ; 同一位置, 两个链 = 两个名字
;;;
;;; 引用在源码里写成链: (jal x0 (g)) / (jal ra (b g))。
;;; 裸原子不当引用(寄存器、立即数都是裸原子), 所以本层不需要认识任何助记符。
;;;
;;; 输出里 label 的链换成**完整链**(模块前缀 + 本地链), 引用改写成完整链。
;;; 之后的层看到的全是完整链, 不知道模块存在。链 -> 偏移 是 layout 的事。

(require (only-in "../sexp.rkt"
                  form? name? path? normalize-path as-items label-expr?))

(provide name?
         path?
         flatten-program
         flatten-inputs
         flatten-items)

;; ---------------------------------------------------------------------------
;; 模块声明
;; ---------------------------------------------------------------------------

;; 一个模块的声明。
;;   provides    : (listof (cons 本地链 外部链))；`(cons #f #f)` 表示 (provide *)
;;   requires    : (listof require-decl)
;;   own-labels  : (listof 本地链)  直接定义在这个模块里的 label（逆序，见 reverse）
(struct mod (name provides requires own-labels) #:mutable)

;; target: 模块完整链; prefix: symbol|#f; renames: (listof (cons 外部链 本地链))
(struct require-decl (target prefix renames) #:transparent)

;; 一次 flatten 用到的全局状态
(struct state (label-index   ; 完整链 -> (cons slot 声明模块)
               modules       ; 模块完整链 -> mod
               imports)      ; 模块链 -> (listof (cons 本地链 绝对链))  require 绑定
  #:mutable)

;; ---------------------------------------------------------------------------
;; 形状
;; ---------------------------------------------------------------------------

(define (module-form? x) (and (form? x) (eq? (car x) 'module)))
(define (label-form? x)  (and (form? x) (eq? (car x) 'label) (path? (cdr x))))
(define (label-ish? x)   (and (form? x) (eq? (car x) 'label)))
(define (clause-form? x key) (and (form? x) (eq? (car x) key)))

(define (relative-path x) (cdr x))

(define (chain-of who x)
  (or (normalize-path x)
      (error 'flatten "~a: expected a name or a chain of names: ~e" who x)))

;; ---------------------------------------------------------------------------
;; 第 1 步: 走一遍, 给每个 item 标 scope, 顺便登记模块和 label
;; ---------------------------------------------------------------------------

;; 按 scope 取模块，没有就建一个。根作用域 () 也走这里（顶点也是一个模块）。
(define (ensure-module! st scope)
  (define m (hash-ref (state-modules st) scope #f))
  (or m
      (let ([m (mod scope '() '() '())])
        (hash-set! (state-modules st) scope m)
        m)))

;; (provide spec ...) -> (listof (cons 本地链 外部链))
(define (parse-provide-clause c)
  (append*
   (for/list ([spec (in-list (cdr c))])
     (cond
       [(eq? spec '*) (list (cons #f #f))]
       [(and (form? spec) (eq? (car spec) 'rename-out))
        (for/list ([pair (in-list (cdr spec))])
          (unless (and (list? pair) (= 2 (length pair)))
            (error 'flatten "rename-out needs (local external) pairs: ~e" pair))
          (cons (chain-of 'rename-out (car pair)) (chain-of 'rename-out (cadr pair))))]
       [else (define ch (chain-of 'provide spec))
             (list (cons ch ch))]))))

;; (require req ...) -> (listof require-decl)
(define (parse-require-clause c)
  (for/list ([r (in-list (cdr c))])
    (cond
      [(and (form? r) (eq? (car r) 'prefix-in))
       (unless (= 3 (length r))
         (error 'flatten "prefix-in needs (prefix-in p: 模块): ~e" r))
       (unless (symbol? (cadr r))
         (error 'flatten "prefix-in wants a symbol prefix: ~e" r))
       (require-decl (chain-of 'require (caddr r)) (cadr r) '())]
      [(and (form? r) (eq? (car r) 'rename-in))
       (require-decl
        (chain-of 'require (cadr r)) #f
        (for/list ([pair (in-list (cddr r))])
          (unless (and (list? pair) (= 2 (length pair)))
            (error 'flatten "rename-in needs (external local) pairs: ~e" pair))
          (cons (chain-of 'rename-in (car pair)) (chain-of 'rename-in (cadr pair)))))]
      [else (require-decl (chain-of 'require r) #f '())])))

;; 返回这一层的 annotated item 列表: (cons scope item)
(define (annotate items scope st)
  (append*
   (for/list ([it (in-list items)])
     (cond
       [(module-form? it)
        (unless (and (>= (length it) 2) (name? (cadr it)))
          (error 'flatten "module needs a name: ~e" it))
        (define full (append scope (list (cadr it))))
        (when (hash-has-key? (state-modules st) full)
          (error 'flatten "module ~s is defined twice" full))
        (define m (mod full '() '() '()))
        (hash-set! (state-modules st) full m)
        (annotate (cddr it) full st)]

       [(clause-form? it 'provide)
        (define m (ensure-module! st scope))
        (set-mod-provides! m (append (mod-provides m) (parse-provide-clause it)))
        '()]

       [(clause-form? it 'require)
        (define m (ensure-module! st scope))
        (set-mod-requires! m (append (mod-requires m) (parse-require-clause it)))
        '()]

       [(label-ish? it)
        (unless (label-form? it)
          (error 'flatten "label needs at least one name, and only names: ~e" it))
        (list (cons scope it))]

       [else (list (cons scope it))]))))

;; ---------------------------------------------------------------------------
;; 第 2 步: label 表 (完整链 -> (slot . 声明模块))
;;
;; slot = 第几段连续的 label 组。展平后相邻的 label 形式是同一个位置。
;; 同一条链出现在两个不同位置 => 报错。
;; ---------------------------------------------------------------------------

(define (index-labels! runs st)
  (define slot -1)
  (for ([annotated (in-list runs)])
    (define previous-was-label? #f)
    (for ([entry (in-list annotated)])
      (define scope (car entry))
      (define it (cdr entry))
      (cond
        [(label-form? it)
         (unless previous-was-label? (set! slot (add1 slot)))
         (set! previous-was-label? #t)
         (define full (append scope (relative-path it)))
         (define known (hash-ref (state-label-index st) full #f))
         (cond
           [(not known)
            (hash-set! (state-label-index st) full (cons slot scope))
            (define m (ensure-module! st scope))
            (set-mod-own-labels! m (cons (strip-prefix scope full) (mod-own-labels m)))]
           [(= (car known) slot) (void)]      ; 同位置重复写同一个名字: 忽略
           [else (error 'flatten "label ~s is defined in two places" full)])]
        [else (set! previous-was-label? #f)]))))

(define (strip-prefix prefix lst) (list-tail lst (length prefix)))

;; ---------------------------------------------------------------------------
;; 第 3 步: 解析模块
;;   imports(模块)  = require 绑定的 (本地链 . 绝对链)
;;   provides(模块) = 导出名      (外部链 . 绝对链)
;; 两者互相依赖(provide 可以 re-export require 进来的东西), 所以用**不动点**:
;; 反复用对方的 provides 重算自己的 imports, 再重算自己的 provides, 直到不再变化。
;; 解不出来的条目在收敛后统一报错。
;; ---------------------------------------------------------------------------

(define (must-module st name)
  (or (hash-ref (state-modules st) name #f)
      (error 'flatten "undefined module ~s (known: ~a)"
             name (sort (hash-keys (state-modules st)) chain<?))))

(define (chain<? a b) (string<? (format "~a" a) (format "~a" b)))

;; 一个模块能看到的全部 require 绑定
(define (imports-of st name)
  (hash-ref (state-imports st) name '()))

;; 在"某个模块里"把一个本地链解析成绝对链:
;;   require 绑定(本模块) -> 本模块或子模块里定义的 label
(define (resolve-in-module st name local)
  (define hit (assoc local (imports-of st name)))
  (cond
    [hit (cdr hit)]
    [else
     (define full (append name local))
     (define known (hash-ref (state-label-index st) full #f))
     (and known full)]))

;; 一个模块导出了什么: (listof (cons 外部链 绝对链))
;;   (provide *)   -> 自有 label
;;   具名的        -> 先看本模块/子模块里有没有这个 label, 再看自己的 require 绑定(re-export)
;; 解不出来的条目先跳过 —— 迭代到不动点后再统一报错(见 resolve-modules!)。
(define (module-provides st name provides-map)
  (define m (must-module st name))
  (append*
   (for/list ([p (in-list (mod-provides m))])
     (cond
       [(not (car p))
        (for/list ([local (in-list (reverse (mod-own-labels m)))])   ; own 是 cons 出来的, 翻回源顺序
          (cons local (append name local)))]
       [else
        ;; resolve-in-module 已经先查 require 绑定(re-export), 再查本地/子模块的 label
        (define abs (resolve-in-module st name (car p)))
        (if abs (list (cons (cdr p) abs)) '())]))))

(define (module-imports st name provides-map)
  (append*
   (for/list ([r (in-list (mod-requires (must-module st name)))])
     ;; 目标模块必须存在; 不存在就在这一步报, 别等到引用解析
     (define target (require-decl-target r))
     (must-module st target)
     (define prefix (require-decl-prefix r))
     (define renames (require-decl-renames r))
     (for/list ([p (in-list (hash-ref provides-map target '()))])
       (define external (car p))
       (define absolute (cdr p))
       (define renamed (assoc external renames))
       (define local
         (cond
           [renamed (cdr renamed)]
           [prefix (list (string->symbol (format "~a~a" prefix (car external))))]
           [else external]))
       (cons local absolute)))))

;; 不动点: imports 依赖对方 provides, provides 又可能依赖自己的 imports(re-export)。
;; 允许 require 成环 —— 这里只是名字解析, 不涉及初始化顺序。
;; 涨不上去的 provide 条目最后统一报错。
(define (resolve-modules! st)
  (define mods (sort (hash-keys (state-modules st)) chain<?))
  (define provides (make-hash))
  (for ([n (in-list mods)]) (hash-set! provides n '()))

  (let loop ([round 0])
    (when (> round 100)
      (error 'flatten "module resolution did not converge"))
    (define changed? #f)
    ;; imports: 由各模块当前 provides 算
    (for ([n (in-list mods)])
      (define imports (module-imports st n provides))
      (unless (equal? imports (imports-of st n))
        (hash-set! (state-imports st) n imports)
        (set! changed? #t)))
    ;; provides: 由 imports + 自有 label 重算
    (for ([n (in-list mods)])
      (define new (module-provides st n provides))
      (unless (equal? new (hash-ref provides n '()))
        (hash-set! provides n new)
        (set! changed? #t)))
    (when changed? (loop (add1 round))))

  ;; 校验
  (for ([n (in-list mods)])
    (define m (must-module st n))
    ;; 1) 每个 provide 条目都必须解得出来
    (define got (hash-ref provides n '()))
    (for ([p (in-list (mod-provides m))] #:when (car p))
      (unless (assoc (cdr p) got)
        (error 'flatten "module ~s provides ~s, but it is not defined there"
               n (car p))))
    ;; 2) 同一个短名不能来自两个不同目标
    (define imports (imports-of st n))
    (define seen (make-hash))
    (for ([b (in-list imports)])
      (define prev (hash-ref seen (car b) #f))
      (when (and prev (not (equal? prev (cdr b))))
        (error 'flatten "module ~s: ~s is required from two places (~s and ~s)"
               n (car b) prev (cdr b)))
      (hash-set! seen (car b) (cdr b)))
    ;; 3) require 进来的名字不能和本模块直接定义的 label 撞
    (for ([b (in-list imports)])
      (define known (hash-ref (state-label-index st) (append n (car b)) #f))
      (when (and known (equal? (cdr known) n))
        (error 'flatten "module ~s: ~s is both defined here and required"
               n (car b))))))

;; ---------------------------------------------------------------------------
;; 第 4 步: 解析引用
;;   由内到外: 先 require 绑定, 再本地 label(只认"祖先或自己"模块里定义的)
;; ---------------------------------------------------------------------------

(define (ancestors-and-self scope)
  (let loop ([s scope] [acc '()])
    (cond
      [(null? s) (reverse (cons '() acc))]
      [else (loop (drop-right s 1) (cons s acc))])))

(define (prefix-of? p s)
  (and (<= (length p) (length s)) (equal? p (take s (length p)))))

;; 注意: 本环境的 for/first 只取**第一次迭代**的值(不像文档说的"第一个非 #f"),
;; 所以这里一律用 for/or。别再换回去。
(define (resolve-ref st scope ref)
  (define levels (ancestors-and-self scope))            ; 由内到外: 自己, 父, ..., 根
  (or (for/or ([m (in-list levels)])
        (define hit (assoc ref (imports-of st m)))
        (and hit (cdr hit)))
      (for/or ([p (in-list levels)])
        (define full (append p ref))
        (define known (hash-ref (state-label-index st) full #f))
        (and known (prefix-of? (cdr known) scope) full))
      #f))

;; ---------------------------------------------------------------------------
;; 第 5 步: 输出
;; ---------------------------------------------------------------------------

(define (rewrite-operand st scope x)
  (define (resolve ref)
    (or (resolve-ref st scope ref)
        (error 'flatten "undefined label ~s (module ~s)" ref scope)))
  (cond
    [(path? x) (resolve x)]
    [(label-expr? x) (cons (car x) (cons (resolve (cadr x)) (cddr x)))]
    [else x]))

(define (rewrite-operands item scope st)
  (cons (car item)
        (for/list ([x (in-list (cdr item))]) (rewrite-operand st scope x))))

(define (resolve-items annotated st)
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
         (values (cons (rewrite-operands it scope st) rev-out) #f emitted-here)])))
  (reverse rev-out))

;; ---------------------------------------------------------------------------
;; 入口
;; ---------------------------------------------------------------------------

;; flatten-inputs : (listof 输入) -> (values (listof 扁平 input) 名字表)
;;   第一个返回值与输入一一对应, 顺序不变。
;;   多个输入共享一张名字表/模块表, 所以 (require 别的输入里的模块) 能查到。
(define (flatten-inputs inputs)
  (define st (state (make-hash) (make-hash) (make-hash)))
  (define runs
    (for/list ([in (in-list inputs)])
      (annotate (as-items in) '() st)))
  (index-labels! runs st)
  (resolve-modules! st)
  (values (for/list ([run (in-list runs)]) (resolve-items run st))
          ;; 对外保持老形状: 链 -> slot（scope 是我们内部用的）
          (for/hash ([(chain entry) (in-hash (state-label-index st))])
            (values chain (car entry)))))

;; flatten-program : (listof item) -> (listof item)   ; 单个输入
(define (flatten-program prog)
  (define-values (outs _) (flatten-inputs (list prog)))
  (car outs))

;; flatten-items : 程序体 -> (values 扁平 item 列表 名字表)
(define (flatten-items items)
  (flatten-inputs (list items)))
