#lang racket
;;; layout/layout.rkt
;;;
;;; 布局计算: program + data + layout 输入 -> ((segments ...) (symbols ...) (problems ...))
;;; 只算, 不选择: 不升级远形式、不造 label、不填 scratch、不重排。
;;;
;;; 输入:
;;;   program : dce 输出的 program
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
;;;   - 单位 = analyze 的块(代码) / 游程 run(数据, 没有控制流)
;;;   - place 行按**精确链**匹配块头或数据游程的 label
;;;   - 命中的块是一个 region 的锚点; 之后直到下一个锚点的块跟随它
;;;   - 段内顺序 = 源顺序; 不做前缀、不做按 kind 的自动落位
;;;   - 放完检查 fallthrough: 顺序后继必须紧挨在后面, 否则 broken-fallthrough

(require "../sexp.rkt"
         "forms.rkt"
         (only-in "../target.rkt" target-xlen)
         ;; la 的近形式够不够得着: 和 encode 用同一个判据
         (only-in "../../riscv-help/main.rkt" fits-auipc-pair?)
         (only-in "../analyze/analyze.rkt" program? program-blocks program-flows
                  block-head block-items flow-fallthrough))

(provide layout-program
         as-items
         layout-problems
         symbol-row       ; 符号行查找 (enable 也要用)
         symbol-address
         (struct-out run))

;; ---------------------------------------------------------------------------
;; 输入整形
;; ---------------------------------------------------------------------------



(define (clauses input key)
  (for/list ([x (in-list (as-items input))]
             #:when (and (form? x) (eq? (car x) key)))
    x))

;; ---------------------------------------------------------------------------
;; 段表 / place 行
;; ---------------------------------------------------------------------------

(struct segment (name kind start end align) #:transparent)

;; 段声明的形状只有一种: (segment (name s) (kind code) (start x) (end y) (align n))
;; 产物多 (items …) (size …)，最终产物 (build) 把 items 换成 (bytes …)。
(define (segment-field* s key)
  (define hit (assoc key (cdr s)))
  (and hit (cadr hit)))

(define (parse-segments input)
  (append*
   (for/list ([cl (in-list (clauses input 'segments))])
     (for/list ([s (in-list (cdr cl))])
       (define name  (and (segment-form? s) (segment-field* s 'name)))
       (define kind  (and (segment-form? s) (segment-field* s 'kind)))
       (define start (and (segment-form? s) (segment-field* s 'start)))
       (define end   (and (segment-form? s) (segment-field* s 'end)))
       (define align (and (segment-form? s) (segment-field* s 'align)))
       (unless (and (symbol? name)
                    (segment-kind? kind)
                    (exact-nonnegative-integer? start)
                    (exact-nonnegative-integer? end)
                    (exact-positive-integer? align))
         (error 'layout "bad segment: ~e" s))
       (segment name kind start end align)))))

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

;; 代码: analyze/dce 的块(struct)
(define (program-parts prog)
  (unless (program? prog)
    (error 'layout "program must be analyze/dce output ((blocks ...) (flows ...)); got: ~e" prog))
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
;;           只给"要改 item 的层"(relax)用来精确定位; encode 不关心

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
       ;;
       ;; 产物里写**事实**不写请求: (align 8) -> (pad 补出来的字节数)。
       ;; 这样 encode 不需要再算一遍对齐公式, 只需要决定这 n 个字节填什么。
       (define pad (modulo (- n (modulo (+ (segment-start seg) cursor) n)) n))
       (emit! (list 'pad pad) pad origin)]
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

;; 符号行: (symbol 链 段名 偏移 绝对地址)
(define (collect-symbols measured-segs)
  (for*/list ([m (in-list measured-segs)]
              [entry (in-list (measured-items m))]
              #:when (label-form? (caddr entry)))
    (define off (cadr entry))
    (define path (cdr (caddr entry)))
    (define seg (measured-segment m))
    (list 'symbol path (segment-name seg) off (+ (segment-start seg) off))))

(define (symbol-row symbols path)
  (and path (findf (lambda (row) (equal? (cadr row) path)) symbols)))

;; 绝对地址在最后一列
(define (symbol-address row) (last row))

;; ---------------------------------------------------------------------------
;; 校验: 只报 problems, 不抛异常。
;; 四类各一个小函数, 由 verify 逐 item 调用:
;;   control  目标存在 / 距离够
;;   scratch  空槽(要不要填交给 relax / 未实现的寄存器层)
;;   la       8 字节的 auipc+addi 够不够得着
;;   value    数据里的地址字: 链存在 / 放得进宽度
;; ---------------------------------------------------------------------------

;; 一个 item 的上下文: 四个小函数都要这几样, 装起来免得每个都 7 个参数
(struct site (seg off item here origin symbols report) #:transparent)

(define (report! s p) ((site-report s) p))

(define (check-control s)
  (define it (site-item s))
  (when (control-form? it)
    (define row (symbol-row (site-symbols s) (normalize-path (control-target it))))
    (cond
      [(not row) (report! s `(undefined-target ,(site-seg s) ,(site-off s) ,it))]
      [else
       ;; range 是区间 (lo . hi); 自带偏置的远形式在表里已经移过了
       (define d (- (symbol-address row) (site-here s)))
       (define range (form-range it))
       (when (and range (not (<= (car range) d (cdr range))))
         (report! s `(needs-far ,(site-seg s) ,(site-off s) ,it ,d ,(site-origin s))))])))

(define (check-scratch s)
  (define it (site-item s))
  (when (scratch-hole? it)
    (report! s `(scratch-hole ,(site-seg s) ,(site-off s) ,it ,(site-origin s)))))

;; (la rd [tmp] 链): 近形式够不够得着? 远形式要 scratch 寄存器, 属于未实现的那一层。
(define (check-la s)
  (define it (site-item s))
  (when (la-form? it)
    (define row (symbol-row (site-symbols s) (normalize-path (last it))))
    (cond
      [(not row) (report! s `(undefined-target ,(site-seg s) ,(site-off s) ,it))]
      [else
       (define d (- (symbol-address row) (site-here s)))
       (unless (fits-auipc-pair? d target-xlen)
         (report! s `(la-too-far ,(site-seg s) ,(site-off s) ,it ,d ,(site-origin s))))])))

;; 数据里的地址字: 链在不在 + 地址放不放得进宽度。
;; 整数不用查(expand-data 已经按宽度查过值域); 只有 label+ 要等地址才知道。
(define (check-value s)
  (define it (site-item s))
  (when (value-form? it)
    (define v (value-payload it))
    (when (label-expr? v)
      (define row (symbol-row (site-symbols s) (label-expr-chain v)))
      (cond
        [(not row) (report! s `(undefined-target ,(site-seg s) ,(site-off s) ,it))]
        [else
         (define n (+ (symbol-address row) (label-expr-addend v)))
         (define bits (* 8 (value-width it)))
         ;; 和 expand-data 同一条规则: 有符号或无符号能放进 bits 位即可
         (unless (<= (- (expt 2 (sub1 bits))) n (sub1 (expt 2 bits)))
           (report! s `(value-out-of-range ,(site-seg s) ,(site-off s) ,it ,n)))]))))

(define (verify measured-segs symbols report)
  (for ([m (in-list measured-segs)])
    (define seg (measured-segment m))
    (for ([entry (in-list (measured-items m))])
      (define off (cadr entry))
      (define it (caddr entry))
      (define s (site (segment-name seg) off it
                      (+ (segment-start seg) off)
                      (hash-ref (measured-origins m) off #f)
                      symbols report))
      (check-control s)
      (check-scratch s)
      (check-la s)
      (check-value s))))

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
  (define data-by-seg (place-runs (split-runs (as-items data)) rules matched problem!))

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
