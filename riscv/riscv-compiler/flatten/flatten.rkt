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
;;; 引用在源码里写成链: (jal x0 (g)) / (jal x1 (b g))。
;;; 裸原子不当引用(寄存器、立即数都是裸原子), 所以本层不需要认识任何助记符。
;;;
;;; 输出里 label 的链换成**完整链**(模块前缀 + 本地链), 引用改写成完整链。
;;; 之后的层看到的全是完整链, 不知道模块存在。链 -> 偏移 是 layout 的事。

(require (only-in "../sexp.rkt"
                  form? name? path? normalize-path as-items arith-head?)
         "../modules.rkt")

(provide name?
         path?
         flatten-program
         flatten-inputs
         flatten-items)

;; 一次 flatten 用到的全局状态
(struct state (label-index   ; 完整链 -> (cons slot 声明模块)
               modules       ; 模块完整链 -> module-decl
               own           ; 模块链 -> 本模块直接定义的 label 本地链（源顺序）
               imports       ; 模块链 -> (listof (cons 本地链 绝对链))  require 绑定
               externs)      ; 外部符号的链 -> #t（输入侧的 link 表给的名字）
  #:mutable)

;; ---------------------------------------------------------------------------
;; 形状
;; ---------------------------------------------------------------------------

(define (label-form? x)  (and (form? x) (eq? (car x) 'label) (path? (cdr x))))
(define (label-ish? x)   (and (form? x) (eq? (car x) 'label)))

(define (relative-path x) (cdr x))

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
        [(and (label-ish? it) (not (label-form? it)))
         (error 'flatten "label needs at least one name, and only names: ~e" it)]
        [(label-form? it)
         (unless previous-was-label? (set! slot (add1 slot)))
         (set! previous-was-label? #t)
         (define full (append scope (relative-path it)))
         (define known (hash-ref (state-label-index st) full #f))
         (cond
           [(not known)
            (hash-set! (state-label-index st) full (cons slot scope))
            (define local (strip-prefix scope full))
            (hash-update! (state-own st) scope (lambda (l) (append l (list local))) '())]
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

;; ---------------------------------------------------------------------------
;; 导出集合: 这一个编译单元对外可见的名字, 用**绝对链**表示
;;
;;   'all       全单元没有任何 (provide …) 子句 -> 平铺镜像语义: 一切都可见
;;   (链 …)     各模块 provide 的并集(取绝对链), 去重后按链排序
;;
;; 为什么取绝对链而不是 provide 里写的名字: 绝对链是流水线里唯一的名字身份
;; (flatten 之后所有层只认它), link 表的行也正是按它排的。rename-out 里的
;; 外部名只在**本单元内**的 require 绑定里有意义; 跨单元怎么称呼它属于输入侧
;; 的事, 等做输入时再定(那时可能要给 link 表加别名行)。
;;
;; 注意: 只要**有** provide 子句, 默认私有就生效 —— 没写的就不导出。
;; 这是 flatten 的模块规则(“默认私有”), 导出集合只是把它记下来, 不另立规则。
;; ---------------------------------------------------------------------------

(define (exports-of st provides)
  (define mods (hash-keys (state-modules st)))
  (if (for/or ([n (in-list mods)])
        (pair? (module-decl-provides (hash-ref (state-modules st) n))))
      (sort (remove-duplicates
             (append* (for/list ([n (in-list mods)])
                        (for/list ([p (in-list (hash-ref provides n '()))])
                          (cdr p)))))
            chain<?)
      'all))

;; ---------------------------------------------------------------------------
;; 第 4 步: 解析引用
;;   由内到外: 先 require 绑定, 再本地 label(只认"祖先或自己"模块里定义的)
;; ---------------------------------------------------------------------------

(define (prefix-of? p s)
  (and (<= (length p) (length s)) (equal? p (take s (length p)))))

;; 注意: 本环境的 for/first 只取**第一次迭代**的值(不像文档说的"第一个非 #f"),
;; 所以这里一律用 for/or。别再换回去。
(define (resolve-ref st scope ref)
  (define levels (ancestors-and-self scope))            ; 由内到外: 自己, 父, ..., 根
  (or (for/or ([m (in-list levels)])
        (define hit (assoc ref (hash-ref (state-imports st) m '())))
        (and hit (cdr hit)))
      (for/or ([p (in-list levels)])
        (define full (append p ref))
        (define known (hash-ref (state-label-index st) full #f))
        (and known (prefix-of? (cdr known) scope) full))
      ;; 外部符号: 名字由输入侧的 link 表保证存在, 地址在那边。
      ;; 只按**写全的名字**认(不套模块前缀): 外部名字不是本单元的 label。
      (and (hash-ref (state-externs st) ref #f) ref)
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
    ;; 地址表达式: 递归进去, 只重写其中的链; +/− 和整数不动
    [(arith-head? x) (cons (car x) (for/list ([a (in-list (cdr x))])
                                    (rewrite-operand st scope a)))]
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

;; flatten-inputs : (listof 输入) [#:externs 外部符号链]
;;                  [#:extern-provides 外部模块的 label-provides]
;;                  [#:struct-provides struct 的 provide 表（用来跳过 struct-only 条目）]
;; -> (values (listof 扁平 input) 名字表 导出集合 label-provides module-requires)
;;   第一个返回值与输入一一对应, 顺序不变。
;;   多个输入共享一张名字表/模块表, 所以 (require 别的输入里的模块) 能查到。
;;   导出集合 = 绝对链列表(已去重排序), 或 'all(全单元没有 provide 子句)。
;;   label-provides = (provides (module ...)) 形状，供下一份编译的 require 使用。
(define (flatten-inputs inputs
                        #:externs [externs '()]
                        #:extern-provides [extern-provides '()]
                        #:struct-provides [struct-provides '()])
  (define extern-names (make-hash))
  (for ([c (in-list externs)]) (hash-set! extern-names c #t))
  (define st (state (make-hash) (make-hash) (make-hash) (make-hash) extern-names))
  (define runs
    (for/list ([in (in-list inputs)])
      (collect-modules (as-items in) '() (state-modules st))))
  (index-labels! runs st)
  (define extern-provides-map
    (parse-extern-provides extern-provides 'label-provides))
  ;; struct 和 label 是独立名字空间：struct-only provide 不该让 label 层报错。
  (define struct-provide-map
    (parse-extern-provides struct-provides 'struct-provides))
  ;; struct 层已经知道的外部模块，即使没有 label provide，也是“存在的模块”；
  ;; 让 require 它不报 undefined module（只是不导入任何 label）。
  (for ([(scope _rows) (in-hash struct-provide-map)])
    (unless (hash-has-key? extern-provides-map scope)
      (hash-set! extern-provides-map scope '())))
  (define allow (make-hash))
  (for ([(scope rows) (in-hash struct-provide-map)])
    (for ([p (in-list rows)])
      (hash-set! allow (cons scope (car p)) #t)))
  (define-values (imports provides unresolved)
    (resolve-modules (state-modules st)
                     #:declarations (state-label-index st)
                     #:own (state-own st)
                     #:extern-provides extern-provides-map
                     #:allow-provides allow))
  (for ([u (in-list unresolved)])
    (define scope (car u))
    (define local (cadr u))
    (error 'flatten "module ~s provides ~s, but it is not defined there"
           scope local))
  (set-state-imports! st imports)
  (values (for/list ([run (in-list runs)]) (resolve-items run st))
          ;; 对外保持老形状: 链 -> slot（scope 是我们内部用的）
          (for/hash ([(chain entry) (in-hash (state-label-index st))])
            (values chain (car entry)))
          (exports-of st provides)
          ;; unit 只描述本单元；外部模块由 extern-units 带进来。
          (provides->sexp provides)
          (requires->sexp (state-modules st))))

;; flatten-program : (listof item) -> (listof item)   ; 单个输入
(define (flatten-program prog
                         #:externs [externs '()]
                         #:extern-provides [extern-provides '()]
                         #:struct-provides [struct-provides '()])
  (define-values (outs _names _exports _provides _requires)
    (flatten-inputs (list prog)
                    #:externs externs
                    #:extern-provides extern-provides
                    #:struct-provides struct-provides))
  (car outs))

;; flatten-items : 程序体 -> (values 扁平 item 列表 名字表 导出集合)
(define (flatten-items items
                       #:externs [externs '()]
                       #:extern-provides [extern-provides '()]
                       #:struct-provides [struct-provides '()])
  (define-values (outs names exports _provides _requires)
    (flatten-inputs (list items)
                    #:externs externs
                    #:extern-provides extern-provides
                    #:struct-provides struct-provides))
  (values outs names exports))
