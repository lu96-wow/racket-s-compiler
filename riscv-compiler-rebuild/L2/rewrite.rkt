#lang racket
;;; L2/rewrite.rkt
;;;
;;; L2 只做一件事: 按表替换。
;;;
;;   认识的拼写(同一行的任意一个名字) + 形状匹配  -> 按表展开
;;;   其他一切(不认识的头 / 形状不对 / 原子 / quote 数据) -> 原样透传, 不报错
;;;
;; 层对外形状是普通 list:
;;;   输入  '((form) (form) ...)
;;;   输出  '((form) (form) ...)      ; 里面已按表换过
;;; 内部的 rewrite-all 只看单个 form / 树, 代码里的 quote 当数据, 不进去。
;;;
;; 所以本层不需要 scratch / gensym / reloc; 每条规则只做缩短/换位,
;;; 从外到内走一遍即收敛(对结果再跑一次是不动点; 表里写出自环则报错)。
;;;
;;; 本层不判断"展开结果是不是真指令": RISC-V 的指令/扩展太多, 名单不在这里维护,
;;; 表里写了后端不认识的东西, 到后端自然报错。
;;;
;;; 数据在 table.rkt: 按扩展拆成 table-*.rkt, 聚合出一张替换表
;;; (一行一个伪指令, 名字平级, 个数不定, 都按同一组规则重写)。
;;; 本文件只放逻辑: 建索引、匹配、遍历; 建表时顺手自检。

(require "table.rkt")

(provide rewrite-item
         ;; 数据
         rewrite-rows
         directive-heads
         reserved-heads
         ;; 表(建好的索引)
         (struct-out table)
         make-table
         row-names
         row-rules
         default-table
         pseudo-names
         rules
         ;; 查询
         pseudo-name?
         rules-for
         validate-rows!
         ;; 变换
         rewrite-one
         rewrite-all
         rewrite-program
         program-items
         ;; 验证
         pseudo-leftover?
         fully-rewritten?
         ;; 匹配基础设施
         form?
         pattern-var?
         pat-match
         subst)

;; 保留字: 名字不许占用指令头(L1 对它们有语义, 例如 quote)
(define reserved-heads directive-heads)

;; ---------------------------------------------------------------------------
;; sexp 匹配 / 替换
;; ---------------------------------------------------------------------------

;; 是不是一个真列表(代码形式的形状)
(define (form? x)
  (and (pair? x) (list? x)))

;; ?x ?d ?off ... 是模式变量; 裸 ? 不算
(define (pattern-var? x)
  (and (symbol? x)
       (let ([s (symbol->string x)])
         (and (> (string-length s) 1)
              (char=? (string-ref s 0) #\?)))))

;; pat-match : any any [alist] -> alist | #f
(define (pat-match pat form [b '()])
  (cond
    [(pattern-var? pat)
     (define prior (assq pat b))
     (cond [(not prior) (cons (cons pat form) b)]
           [(equal? (cdr prior) form) b]
           [else #f])]
    [(pair? pat)
     (and (pair? form)
          (= (length pat) (length form))
          (let loop ([ps pat] [fs form] [b b])
            (cond [(null? ps) b]
                  [else
                   (define b* (pat-match (car ps) (car fs) b))
                   (and b* (loop (cdr ps) (cdr fs) b*))])))]
    [else (and (equal? pat form) b)]))

;; subst : any alist -> any
(define (subst tmpl b)
  (cond
    [(pattern-var? tmpl)
     (cond [(assq tmpl b) => cdr]
           [else tmpl])]
    [(pair? tmpl) (cons (subst (car tmpl) b) (subst (cdr tmpl) b))]
    [else tmpl]))

;; ---------------------------------------------------------------------------
;; 从表推出视图 + 建表时自检
;;
;; 名字个数不定: 一行前面有几个 symbol 就有几个名字, 最少 1 个, 上限没有。
;; 所以 `(l8 ...)` 和 `(l8 ld8 lw8 ldw8 ...)` 是同一种行, 处理方式完全一样。
;; ---------------------------------------------------------------------------

;; 一行里: 前面的 symbol 是名字, 后面的 list 是规则
(define (row-names row) (takef row symbol?))
(define (row-rules row) (dropf row symbol?))

;; 建好的表: 行 + 名字->规则 索引 + 所有名字 + 所有规则
(struct table (rows rules-by-name names rules) #:transparent)

;; 建表: 校验整张表
;;   名字重复(同行/跨行)、占用保留字、规则形状不对、模板不是 form,
;;   或者一行只有名字没规则, 都直接报错。
(define (make-table rows [reserved reserved-heads])
  (define rules-by-name (make-hash))
  (define names '())
  (define all-rules '())
  (for ([row (in-list rows)])
    (unless (and (list? row) (pair? row) (symbol? (car row)))
      (error 'table "row must be (name ... (operand-pattern template) ...): ~e" row))
    (define row-ns (row-names row))
    (define row-rs (row-rules row))
    (when (null? row-rs)
      (error 'table "row has names but no rules: ~e" row))
    (for ([s (in-list row-ns)])
      (when (memq s reserved)
        (error 'table "spelling ~a is reserved" s))
      (when (hash-has-key? rules-by-name s)
        (error 'table "spelling ~a appears twice" s))
      (hash-set! rules-by-name s row-rs)
      (set! names (cons s names)))
    (for ([r (in-list row-rs)])
      (unless (and (list? r) (= 2 (length r)))
        (error 'table "rule must be (operand-pattern template): ~e" r))
      (define pat (car r))
      (define tmpl (cadr r))
      (unless (list? pat)
        (error 'table "operand pattern must be a list: ~e" pat))
      (unless (form? tmpl)
        (error 'table "template must be a form: ~e" tmpl)))
    (set! all-rules (append all-rules row-rs)))
  (table rows rules-by-name (reverse names) all-rules))

;; 默认表: 用 table.rkt 的 `rewrite-rows` 建, 建表时已经自检过一遍
(define default-table (make-table rewrite-rows))

;; 视图
(define pseudo-names (table-names default-table))
(define rules (table-rules default-table))

;; 测试/自定义时用别的表自检
(define (validate-rows! [rows rewrite-rows])
  (make-table rows)
  (void))

;; ---------------------------------------------------------------------------
;; 查表
;; ---------------------------------------------------------------------------

;; 这个拼写认识吗
(define (pseudo-name? h [tbl default-table])
  (and (symbol? h) (hash-has-key? (table-rules-by-name tbl) h)))

;; 某个拼写的规则表; 不认识(或不是 symbol)返回 '()
(define (rules-for h [tbl default-table])
  (hash-ref (table-rules-by-name tbl) h '()))

;; ---------------------------------------------------------------------------
;; 单节点重写
;; ---------------------------------------------------------------------------

;; 命中返回展开结果, 否则 #f。
;; 名字不分主次: 拿实际写的头配规则的操作数模式, 所以 l8 / load-8 走同一条规则。
;; 形状不匹配时返回 #f, 调用方保留**原始拼写**, 交给编码器报错。
(define (rewrite-one form [tbl default-table])
  (and (form? form)
       (let ([h (car form)])
         (and (symbol? h)
              (for/or ([r (in-list (rules-for h tbl))])
                (define b (pat-match (cons h (car r)) form))
                (and b (subst (cadr r) b)))))))

;; ---------------------------------------------------------------------------
;; 重写: 只认「item 位置」
;;
;; 一条 item = 一个列表, 头是助记符。item 命中规则就把结果整体再过一遍
;; (展开链一次收敛); 没命中就原样。
;;
;; 操作数是**值**, 不是代码, 一律不进去:
;;   - 链 (a g) 是值(目标/地址), 不会被当成 (a g) 这条指令
;;   - 嵌套写在操作数里的伪指令不展开(展平后不存在这种写法)
;;
;; 会往下走的位置只有两种: item 列表、quote(数据, 屏障)。
;;
;; 表里不小心写出自环(如 (foo ?x) -> (foo ?x))时, 展开链不会收敛,
;; 所以链长有上限, 超了直接报错, 不会卡死。
;; ---------------------------------------------------------------------------

(define max-expand-steps 64)

;; 一条 item: 展开到不再命中
(define (rewrite-item form [tbl default-table])
  (define y (and (form? form) (rewrite-one form tbl)))
  (if y (rewrite-chain y tbl 1) form))

;; 命中后对结果接着重写, 直到不再命中; 走满 max-expand-steps 步就当自环报错
(define (rewrite-chain x tbl steps)
  (cond
    [(>= steps max-expand-steps)
     (error 'rewrite-item "expansion chain longer than ~a steps (cycle in table?): ~e"
            max-expand-steps x)]
    [else
     (define y (and (form? x) (rewrite-one x tbl)))
     (if y (rewrite-chain y tbl (add1 steps)) x)]))

;; item 列表 / 单条 item
(define (rewrite-all x [tbl default-table])
  (define (each items) (map (lambda (i) (rewrite-all i tbl)) items))
  (cond
    [(not (form? x)) x]
    [(eq? (car x) 'quote) x]                             ; 数据, 不进去
    [(pair? (car x)) (each x)]                            ; item 列表
    [else (rewrite-item x tbl)]))

;; ---------------------------------------------------------------------------
;; 验证: 输出中不允许残留任何 P-asm 拼写
;; ---------------------------------------------------------------------------

(define (pseudo-leftover? x [tbl default-table])
  (define (any-left? items) (ormap (lambda (i) (pseudo-leftover? i tbl)) items))
  (cond
    [(not (form? x)) #f]
    [(eq? (car x) 'quote) #f]                             ; 数据, 不进去
    [(pair? (car x)) (any-left? x)]                        ; item 列表
    [else (and (pseudo-name? (car x) tbl) #t)]))

(define (fully-rewritten? x [tbl default-table])
  (not (pseudo-leftover? x tbl)))

;; ---------------------------------------------------------------------------
;; 层入口
;;
;; 程序是普通 list:
;;
;;   (rewrite-program '((load-32 t0 sp 8) L))
;;   => '((lwu t0 sp 8) L)
;;
;; 旧壳 (quote ...) / (begin ...) 也收, 出口一律 plain list。
;; 代码内部的 quote 仍然是数据, rewrite-all 不进去。
;; ---------------------------------------------------------------------------

;; program-items : 去掉旧壳(quote/begin), 拿到 item 列表
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
  (if (and (form? (car items)) (eq? (caar items) 'begin) (= 1 (length items)))
      (cdar items)
      items))

;; rewrite-program : (listof item) -> (listof item)
(define (rewrite-program prog [tbl default-table])
  (rewrite-all (program-items prog) tbl))
