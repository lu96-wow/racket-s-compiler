#lang racket
;;; layout/layout.rkt
;;;
;;; 布局度量: program + data + layout 输入
;;;   -> ((phase measured) (segments ...) (anchors ...) (requests ...) (problems ...))
;;;
;;; 本层只产出“位置”，不产出绝对地址:
;;;   anchors  = label 的身份 + 段 + 段内偏移
;;;   requests = needs-far / scratch-hole / la-too-far（交给 relax 或寄存器层）
;;;   problems = 放置 / 段 / fallthrough / undefined-target
;;;
;;; 绝对地址由 bind-labels 一次性绑定；value 宽度和段容量也在那里做最终检查。
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
         layout-phase
         layout-problems
         layout-requests
         layout-segments
         layout-anchors
         anchor-row
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

(define (measure target seg blks runs problem!)
  (define seg-name (segment-name seg))
  (define seg-kind (segment-kind seg))
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
      [else (emit! it (item-size target it) origin)]))

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

  (measured seg (reverse out) cursor blks origins))

(define (measure-all target segs code-by-seg data-by-seg problem!)
  (for/list ([seg (in-list segs)])
    (define name (segment-name seg))
    (measure target seg (hash-ref code-by-seg name '()) (hash-ref data-by-seg name '()) problem!)))

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
;; anchors / 临时位置
;; ---------------------------------------------------------------------------

;; anchor 行: (anchor 链 段名 偏移) —— 只有位置, 没有绝对地址
(define (collect-anchors measured-segs)
  (for*/list ([m (in-list measured-segs)]
              [entry (in-list (measured-items m))]
              #:when (label-form? (caddr entry)))
    (define off (cadr entry))
    (define path (cdr (caddr entry)))
    (define seg (measured-segment m))
    (list 'anchor path (segment-name seg) off)))

(define (anchor-row anchors path)
  (and path (findf (lambda (row) (equal? (cadr row) path)) anchors)))

;; measured 相内部的临时位置: 链 -> 段 start + 段内偏移。
;; 只在本层用于 needs-far / la-too-far 的距离判断, 不写进产物。
(define (collect-positions measured-segs anchors)
  (define start-of
    (for/hash ([m (in-list measured-segs)])
      (values (segment-name (measured-segment m))
              (segment-start (measured-segment m)))))
  (for/hash ([a (in-list anchors)])
    (values (cadr a) (+ (hash-ref start-of (caddr a)) (cadddr a)))))

;; ---------------------------------------------------------------------------
;; 校验: 只报 problems/requests, 不抛异常。
;;   control  目标存在 / 距离够 -> undefined-target(problem) / needs-far(request)
;;   scratch  空槽 -> scratch-hole(request)
;;   la       8 字节的 auipc+addi 够不够得着 -> la-too-far(request)
;;   value    数据里的地址字: 只查链存在; 宽度等 bind-labels 用最终地址查
;; ---------------------------------------------------------------------------

(struct site (seg off item here origin positions problem! request!) #:transparent)

(define (problem! s p) ((site-problem! s) p))
(define (request! s p) ((site-request! s) p))

(define (check-control s)
  (define it (site-item s))
  (when (control-form? it)
    (define target (normalize-path (control-target it)))
    (define addr (and target (hash-ref (site-positions s) target #f)))
    (cond
      [(not addr) (problem! s `(undefined-target ,(site-seg s) ,(site-off s) ,it))]
      [else
       ;; range 是区间 (lo . hi); 自带偏置的远形式在表里已经移过了
       (define d (- addr (site-here s)))
       (define range (form-range it))
       (when (and range (not (<= (car range) d (cdr range))))
         (request! s `(needs-far ,(site-seg s) ,(site-off s) ,it ,d ,(site-origin s))))])))

(define (check-scratch s)
  (define it (site-item s))
  (when (scratch-hole? it)
    (request! s `(scratch-hole ,(site-seg s) ,(site-off s) ,it ,(site-origin s)))))

;; 地址表达式里的链都在临时位置表里吗? 缺了就报 undefined-target（每条缺的报一次）
(define (check-chains s expr)
  (define ok? #t)
  (for ([c (in-list (address-expr-chains expr))])
    (unless (hash-ref (site-positions s) c #f)
      (set! ok? #f)
      (problem! s `(undefined-target ,(site-seg s) ,(site-off s) ,(site-item s)))))
  ok?)

;; 数据里的值: 本层只保证链存在; 值是否放得进宽度由 bind-labels 用最终地址查。
(define (check-value-chains s)
  (define it (site-item s))
  (when (value-form? it)
    (define v (value-payload it))
    (when (not (exact-integer? v))
      (check-chains s v))))

;; (la rd [tmp] 地址表达式): 近形式 8 字节够不够得着?
;; 远形式需要 scratch 寄存器, 属于未实现的那一层。
(define (check-la target s)
  (define it (site-item s))
  (when (la-form? it)
    (define expr (last it))
    (when (check-chains s expr)
      (define d (- (eval-address expr (lambda (c) (hash-ref (site-positions s) c #f)))
                   (site-here s)))
      (unless (fits-auipc-pair? d (target-xlen target))
        (request! s `(la-too-far ,(site-seg s) ,(site-off s) ,it ,d ,(site-origin s)))))))

(define (verify target measured-segs positions problem! request!)
  (for ([m (in-list measured-segs)])
    (define seg (measured-segment m))
    (for ([entry (in-list (measured-items m))])
      (define off (cadr entry))
      (define it (caddr entry))
      (define s (site (segment-name seg) off it
                      (+ (segment-start seg) off)
                      (hash-ref (measured-origins m) off #f)
                      positions problem! request!))
      (check-control s)
      (check-scratch s)
      (check-la target s)
      (check-value-chains s))))

;; ---------------------------------------------------------------------------
;; 输出
;; ---------------------------------------------------------------------------

(define (layout->sexp measured-segs anchors requests problems)
  (list (list 'phase 'measured)
        (cons 'segments
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
        (cons 'anchors anchors)
        (cons 'requests requests)
        (cons 'problems problems)))

;; ---------------------------------------------------------------------------
;; 入口
;; ---------------------------------------------------------------------------

(define (layout-program target program data layout-input)
  (define segs (parse-segments layout-input))
  (define places (parse-places layout-input))
  (define problems '())
  (define requests '())
  (define (problem! p) (set! problems (cons p problems)))
  (define (request! p) (set! requests (cons p requests)))

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

  (define measured-segs (measure-all target segs code-by-seg data-by-seg problem!))
  (check-fallthrough measured-segs flows problem!)
  (define anchors (collect-anchors measured-segs))
  (define positions (collect-positions measured-segs anchors))
  (verify target measured-segs positions problem! request!)

  (layout->sexp measured-segs anchors (reverse requests) (reverse problems)))

;; 产物字段的便捷访问器(测试/上层用)
(define (layout-field layout key)
  (define hit (assoc key layout))
  (and hit (cdr hit)))

(define (layout-phase layout)
  (define row (assoc 'phase layout))
  (and row (cadr row)))
(define (layout-problems layout) (layout-field layout 'problems))
(define (layout-requests layout) (layout-field layout 'requests))
(define (layout-segments layout) (layout-field layout 'segments))
(define (layout-anchors layout) (layout-field layout 'anchors))
