#lang racket
;;; L5/layout.rkt
;;;
;;; 布局计算: program + data + layout 输入 -> ((segments ...) (symbols ...) (problems ...))
;;; 只算, 不选择: 不升级远形式、不造 label、不填 scratch、不重排。
;;;
;;; 输入:
;;;   program : L4 输出的 program
;;;             blocks : ((block <头 label 链列表> item ...) ...)   ; 身份 + 程序
;;;             flows  : ((flow (succ id ...) (fallthrough id|#f) (root? bool)) ...)
;;;   data    : 普通 item 列表 ((label ...) (bytes ...) (fill n b)
;;;                              (value 宽度 值) (align n) ...)
;;;   layout  : ((segments (segment 名 kind start end align) ...)
;;;              (place 段名 链 ...) ...)
;;;
;;; 代码里没有 section: 段归属只写在 layout 的 place 行里。
;;;
;;; 放置:
;;;   - 单位 = L3 的块(代码) / 游程 run(数据, 没有控制流)
;;;   - place 行按**精确链**匹配块头或数据游程的 label
;;;   - 命中的块是一个 region 的锚点; 之后直到下一个锚点的块跟随它
;;;   - 段内顺序 = 源顺序; 不做前缀、不做按 kind 的自动落位
;;;   - 放完检查 fallthrough: 顺序后继必须紧挨在后面, 否则 broken-fallthrough

(require "forms.rkt"
         ;; la 的近形式够不够得着: 和 L7 用同一个判据
         (only-in "../../riscv-help/main.rkt" fits-auipc-pair?)
         (only-in "../L3/analyze.rkt" program? program-blocks program-flows
                  block-head block-items flow-fallthrough))

(provide layout-program
         program-items
         layout-problems
         (struct-out run))

;; ---------------------------------------------------------------------------
;; 输入整形
;; ---------------------------------------------------------------------------

(define (program-items input)
  (define body
    (cond
      [(and (form? input) (eq? (car input) 'quote) (= 2 (length input)) (list? (cadr input)))
       (cadr input)]
      [(list? input) input]
      [else (list input)]))
  (define items
    (cond
      [(null? body) '()]
      [(pair? (car body)) body]
      [else (list body)]))
  (if (and (= 1 (length items)) (form? (car items)) (eq? (caar items) 'begin))
      (cdar items)
      items))

(define (clauses input key)
  (for/list ([x (in-list (program-items input))]
             #:when (and (form? x) (eq? (car x) key)))
    x))

;; ---------------------------------------------------------------------------
;; 段表 / place 行
;; ---------------------------------------------------------------------------

(struct segment (name kind start end align) #:transparent)

(define (parse-segments input)
  (append*
   (for/list ([cl (in-list (clauses input 'segments))])
     (for/list ([s (in-list (cdr cl))])
       (define ok?
         (and (segment-form? s)
              (= 6 (length s))
              (symbol? (cadr s))
              (segment-kind? (caddr s))
              (exact-nonnegative-integer? (cadddr s))
              (exact-nonnegative-integer? (list-ref s 4))
              (exact-positive-integer? (list-ref s 5))))
       (unless ok? (error 'layout "bad segment: ~e" s))
       (segment (cadr s) (caddr s) (cadddr s) (list-ref s 4) (list-ref s 5))))))

(define (parse-places input)
  (for/list ([cl (in-list (clauses input 'place))])
    (unless (and (>= (length cl) 3) (symbol? (cadr cl)))
      (error 'layout "bad place: ~e" cl))
    (cons (cadr cl)
          (for/list ([c (in-list (cddr cl))])
            (or (normalize-path c) (error 'layout "bad chain in place: ~e" c))))))

;; ---------------------------------------------------------------------------
;; 段表自检
;; ---------------------------------------------------------------------------

(define (validate-segments segs problem!)
  (define names (map segment-name segs))
  (unless (= (length names) (length (remove-duplicates names)))
    (problem! `(segment-name-duplicated ,names)))
  (for ([s (in-list segs)])
    (unless (< (segment-start s) (segment-end s))
      (problem! `(segment-bad-range ,(segment-name s))))
    (unless (zero? (modulo (segment-start s) (segment-align s)))
      (problem! `(segment-misaligned ,(segment-name s) ,(segment-start s) ,(segment-align s)))))
  (define n (length segs))
  (for* ([i (in-range n)] [j (in-range n)] #:when (< i j))
    (define a (list-ref segs i))
    (define b (list-ref segs j))
    (when (and (< (segment-start a) (segment-end b))
               (< (segment-start b) (segment-end a)))
      (problem! `(segment-overlap ,(segment-name a) ,(segment-name b))))))

;; ---------------------------------------------------------------------------
;; 两种放置单位
;; ---------------------------------------------------------------------------

;; 代码: L3/L4 的块(struct)
(define (program-parts prog)
  (unless (program? prog)
    (error 'layout "program must be L3/L4 output ((blocks ...) (flows ...)); got: ~e" prog))
  (values (program-blocks prog) (program-flows prog)))

;; 数据: 从一条 label 到下一条 label 之间的 item
(struct run (labels items) #:transparent)

(define (split-runs items)
  (define runs '())
  (define cur-labels '())
  (define cur-items '())
  (define (flush!)
    (when (or (pair? cur-labels) (pair? cur-items))
      (set! runs (cons (run (reverse cur-labels) (reverse cur-items)) runs))
      (set! cur-labels '())
      (set! cur-items '())))
  (for ([it (in-list items)])
    (cond
      [(label-form? it)
       (when (pair? cur-items) (flush!))
       (set! cur-labels (cons (cdr it) cur-labels))]
      [else (set! cur-items (cons it cur-items))]))
  (flush!)
  (reverse runs))

;; ---------------------------------------------------------------------------
;; 放置
;; ---------------------------------------------------------------------------

(define (rules-of places by-name problem!)
  (for ([p (in-list places)])
    (unless (hash-ref by-name (car p) #f)
      (problem! `(unknown-segment ,(car p)))))
  (append* (for/list ([p (in-list places)]
                      #:when (hash-ref by-name (car p) #f))
             (for/list ([c (in-list (cdr p))]) (cons c (car p))))))

;; 某组 label 命中了哪些段(按规则, 精确匹配); 命中的链记到 matched 里
(define (matching-segments labels rules matched)
  (remove-duplicates
   (for*/list ([chain (in-list labels)]
               [rule (in-list rules)]
               #:when (equal? chain (car rule)))
     (hash-set! matched chain #t)
     (cdr rule))))

;; 代码块: 锚点 + 其后跟随的块; 每项是 (cons 全局下标 块)
(define (place-blocks blocks rules matched problem!)
  (define by-seg (make-hash))                 ; 段名 -> ((idx . block) ...) 源顺序
  (define current (box #f))
  (for ([b (in-list blocks)] [idx (in-naturals)])
    (define entry (cons idx b))
    (define hits (matching-segments (block-head b) rules matched))
    (cond
      [(> (length hits) 1)
       (problem! `(ambiguous-placement ,(car (block-head b)) ,@hits))]
      [(= (length hits) 1)
       (set-box! current (car hits))
       (hash-update! by-seg (car hits) (lambda (l) (append l (list entry))) '())]
      [(unbox current)
       (hash-update! by-seg (unbox current) (lambda (l) (append l (list entry))) '())]
      [else
       (problem! `(unplaced-block ,idx ,(block-head b)))]))
  by-seg)

;; 数据游程: 精确匹配, 不跟随(数据没有顺序执行)
(define (place-runs runs rules matched problem!)
  (define by-seg (make-hash))
  (for ([r (in-list runs)])
    (define labels (run-labels r))
    (cond
      [(null? labels) (problem! `(unlabeled-run ,(run-items r)))]
      [else
       (define hits (matching-segments labels rules matched))
       (cond
         [(null? hits) (problem! `(unplaced ,(car labels)))]
         [(> (length hits) 1) (problem! `(ambiguous-placement ,(car labels) ,@hits))]
         [else
          (hash-update! by-seg (car hits)
                        (lambda (l) (append l (list r)))
                        '())])]))
  by-seg)

;; 段输出顺序 = 段表声明顺序; 每个段都要有 entry(可能是空的)
(define (ensure-segments segs by-seg)
  (for ([s (in-list segs)])
    (unless (hash-has-key? by-seg (segment-name s))
      (hash-set! by-seg (segment-name s) '())))
  by-seg)

;; ---------------------------------------------------------------------------
;; 度量: 段内单游标, align 补齐, 逐条累加
;; ---------------------------------------------------------------------------

(struct measured (segment items size blocks origins) #:transparent)
;; items   : (listof (list 'offset 偏移 item))
;; blocks  : 代码段里块的顺序 (listof (cons 全局下标 block)), 数据段为空
;; origins : 偏移 -> (code 块下标 项下标) | (data 游程下标 项下标)
;;           只给"要改 item 的层"(L6)用来精确定位; L7 不关心

(define (measure seg blks runs problem!)
  (define seg-name (segment-name seg))
  (define seg-kind (segment-kind seg))
  (define capacity (- (segment-end seg) (segment-start seg)))
  (define cursor 0)
  (define out '())

  (define origins (make-hash))

  (define (emit! it sz [origin #f])
    (when origin (hash-set! origins cursor origin))
    (cond
      [(and (eq? (item-kind it) 'data) (eq? seg-kind 'code))
       (problem! `(code-data-mixed ,seg-name ,cursor ,it))]
      [(and (eq? (item-kind it) 'code) (not (eq? seg-kind 'code)))
       (problem! `(data-code-mixed ,seg-name ,cursor ,it))])
    (set! out (cons (list 'offset cursor it) out))
    (set! cursor (+ cursor sz)))

  (define (emit-item! it origin)
    (cond
      [(align-form? it)
       (define n (cadr it))
       ;; "code 段的 align 必须是 4 的倍数"是 ISA 合法性, 不归本层: 只对齐, 不判。
       ;; align 是**绝对地址**对齐: 段 start 不一定被 item 的 n 整除,
       ;; 所以用 (start + cursor) 算, 不能只用段内 cursor。
       (emit! it (modulo (- n (modulo (+ (segment-start seg) cursor) n)) n) origin)]
      [else (emit! it (item-size it) origin)]))

  (for ([e (in-list blks)])
    (define b (cdr e))
    (for ([chain (in-list (block-head b))])
      (emit! (cons 'label chain) 0))
    (for ([it (in-list (block-items b))] [i (in-naturals)])
      (emit-item! it (list 'code (car e) i))))

  (for ([r (in-list runs)] [ri (in-naturals)])
    (for ([chain (in-list (run-labels r))])
      (emit! (cons 'label chain) 0))
    (for ([it (in-list (run-items r))] [i (in-naturals)])
      (emit-item! it (list 'data ri i))))

  (when (and (>= capacity 0) (> cursor capacity))
    (problem! `(segment-overflow ,seg-name ,cursor ,capacity)))

  (measured seg (reverse out) cursor blks origins))

(define (measure-all segs code-by-seg data-by-seg problem!)
  (for/list ([seg (in-list segs)])
    (define name (segment-name seg))
    (measure seg (hash-ref code-by-seg name '()) (hash-ref data-by-seg name '()) problem!)))

;; ---------------------------------------------------------------------------
;; fallthrough 检查: 顺序后继必须紧挨着
;; ---------------------------------------------------------------------------

(define (check-fallthrough measured-segs flows problem!)
  (define where (make-hash))                    ; 块下标 -> (cons 段名 段内序号)
  (define labels-of (make-hash))                ; 块下标 -> 块头 labels
  (for ([m (in-list measured-segs)])
    (for ([e (in-list (measured-blocks m))] [i (in-naturals)])
      (hash-set! where (car e) (cons (segment-name (measured-segment m)) i))
      (hash-set! labels-of (car e) (block-head (cdr e)))))
  (for ([m (in-list measured-segs)])
    (define blks (measured-blocks m))
    (for ([e (in-list blks)] [i (in-naturals)])
      (define idx (car e))
      (define ft (flow-fallthrough (list-ref flows idx)))
      (when ft
        (define nxt (and (< (add1 i) (length blks)) (list-ref blks (add1 i))))
        (unless (and nxt
                     (= (car nxt) ft)
                     (equal? (hash-ref where ft #f)
                             (cons (segment-name (measured-segment m)) (add1 i))))
          (problem! `(broken-fallthrough ,idx ,ft
                                         ,(hash-ref labels-of idx '())
                                         ,(hash-ref labels-of ft '()))))))))

;; ---------------------------------------------------------------------------
;; 符号表
;; ---------------------------------------------------------------------------

(define (collect-symbols measured-segs)
  (for*/list ([m (in-list measured-segs)]
              [entry (in-list (measured-items m))]
              #:when (label-form? (caddr entry)))
    (define off (cadr entry))
    (define path (cdr (caddr entry)))
    (define seg (measured-segment m))
    (list path (segment-name seg) off (+ (segment-start seg) off))))

(define (symbol-row symbols path) (and path (assoc path symbols)))

;; ---------------------------------------------------------------------------
;; 校验: 目标存在 / 距离够 / scratch 空槽 / 地址字能放进宽度 / la 够得着
;; ---------------------------------------------------------------------------

(define (verify measured-segs symbols problem!)
  (for ([m (in-list measured-segs)])
    (define seg (measured-segment m))
    (for ([entry (in-list (measured-items m))])
      (define off (cadr entry))
      (define it (caddr entry))
      (define here (+ (segment-start seg) off))
      (define origin (hash-ref (measured-origins m) off #f))
      (when (control-form? it)
        (define target (normalize-path (control-target it)))
        (define row (symbol-row symbols target))
        (cond
          [(not row) (problem! `(undefined-target ,(segment-name seg) ,off ,it))]
          [else
           (define d (- (cadddr row) here))
           (define range (form-range it))
           ;; range 是区间 (lo . hi); 自带偏置的远形式在表里已经移过了
           (when (and range (not (<= (car range) d (cdr range))))
             (problem! `(needs-far ,(segment-name seg) ,off ,it ,d ,origin)))]))
      (when (scratch-hole? it)
        (problem! `(scratch-hole ,(segment-name seg) ,off ,it ,origin)))
      ;; (la rd [tmp] 链): 8 字节的 auipc+addi 够不够得着?
      ;; 远形式需要 scratch 寄存器, 那属于"动态内存布局 / 寄存器使用"那一层(未实现),
      ;; 所以这里只报问题, 不做远形式。
      (when (la-form? it)
        (define row (symbol-row symbols (normalize-path (last it))))
        (cond
          [(not row) (problem! `(undefined-target ,(segment-name seg) ,off ,it))]
          [else
           (define d (- (cadddr row) here))
           (unless (fits-auipc-pair? d 'rv64)
             (problem! `(la-too-far ,(segment-name seg) ,off ,it ,d ,origin)))]))
      ;; 数据里的地址字: 解析出绝对地址, 查链在不在 + 能不能放进 宽度 个字节。
      ;; 整数不用查(D1 已经按宽度查过值域); 只有 label+ 需要地址才知道。
      (when (value-form? it)
        (define v (value-payload it))
        (when (label-expr? v)
          (define row (symbol-row symbols (label-expr-chain v)))
          (cond
            [(not row) (problem! `(undefined-target ,(segment-name seg) ,off ,it))]
            [else
             (define n (+ (cadddr row) (label-expr-addend v)))
             (define bits (* 8 (value-width it)))
             ;; 和 D1 同一条规则: 有符号或无符号能放进 bits 位即可
             (unless (<= (- (expt 2 (sub1 bits))) n (sub1 (expt 2 bits)))
               (problem! `(value-out-of-range ,(segment-name seg) ,off ,it ,n)))]))))))

;; ---------------------------------------------------------------------------
;; 输出
;; ---------------------------------------------------------------------------

(define (layout->sexp measured-segs symbols problems)
  (list (cons 'segments
              (for/list ([m (in-list measured-segs)])
                (define seg (measured-segment m))
                (list 'segment
                      (list 'name (segment-name seg))
                      (list 'kind (segment-kind seg))
                      (list 'start (segment-start seg))
                      (list 'end (segment-end seg))
                      (list 'align (segment-align seg))
                      (cons 'items (measured-items m))
                      (list 'size (measured-size m)))))
        (cons 'symbols symbols)
        (cons 'problems problems)))

;; ---------------------------------------------------------------------------
;; 入口
;; ---------------------------------------------------------------------------

(define (layout-program program data layout-input)
  (define segs (parse-segments layout-input))
  (define places (parse-places layout-input))
  (define problems '())
  (define (problem! p) (set! problems (cons p problems)))

  (validate-segments segs problem!)
  (define by-name (for/hash ([s (in-list segs)]) (values (segment-name s) s)))
  (define rules (rules-of places by-name problem!))

  (define-values (blocks flows) (program-parts program))
  (define matched (make-hash))             ; 用到过的 place 链
  (define code-by-seg (place-blocks blocks rules matched problem!))
  (define data-by-seg (place-runs (split-runs (program-items data)) rules matched problem!))

  ;; place 里的链一次都没命中: 写错名字, 或指的是块内的位置标记(块不能拆)
  (for ([rule (in-list rules)])
    (unless (hash-ref matched (car rule) #f)
      (problem! `(unmatched-place ,(car rule)))))
  (ensure-segments segs code-by-seg)
  (ensure-segments segs data-by-seg)

  (define measured-segs (measure-all segs code-by-seg data-by-seg problem!))
  (check-fallthrough measured-segs flows problem!)
  (define symbols (collect-symbols measured-segs))
  (verify measured-segs symbols problem!)

  (layout->sexp measured-segs symbols (reverse problems)))

;; 只看 problems 的便捷函数(测试/上层用)
(define (layout-problems layout)
  (define hit (assoc 'problems layout))
  (and hit (cdr hit)))
