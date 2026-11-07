#lang racket
;;; bind-labels/bind.rkt
;;;
;;; 地址绑定: measured-layout -> bound-layout。
;;;
;;; measured 相只有 anchors: (anchor 链 段名 偏移)。
;;; 本层把它们落到绝对地址:
;;;
;;;   (symbol 链 段名 偏移 绝对地址) = 段 start + 偏移
;;;
;;; 顺带做两件只有“最终地址/最终尺寸”才能做的检查:
;;;   - (value 宽度 值) 的值是否放得进宽度
;;;   - 段实际尺寸是否超过 (end - start)
;;;
;;; 本层不改 item、不改 offset/size、不做松弛、不填 scratch、不补跳。
;;; needs-far / scratch-hole / la-too-far 原样留在 requests 里;
;;; 没解决就由 encode 拒绝出产物。

(require racket/list
         "../sexp.rkt"
         (only-in "../layout/layout.rkt"
                  layout-phase layout-origin layout-externs
                  layout-problems layout-requests
                  layout-segments layout-anchors)
         (only-in "../layout/forms.rkt"
                  value-form? value-width value-payload))

(provide bind-labels
         bound-layout?
         layout-symbols
         layout-link
         layout-provides
         symbol-row
         symbol-address
         eval-symbol-address)

;; ---------------------------------------------------------------------------
;; 符号表
;; ---------------------------------------------------------------------------

(define (segment-field seg key)
  (define hit (assoc key (cdr seg)))
  (and hit (cadr hit)))

;; anchor 行 (anchor 链 段名 偏移) -> 符号行 (symbol 链 段名 偏移 绝对地址)
;; 外部符号行: 地址已知的就是 (symbol 链 #f #f 地址) —— 段名/偏移是空的,
;; 但 symbol-address 只取最后一列, 所以下游(eval-symbol-address / encode)零改动。
;; 地址未知(#f)的不进符号表: 它已经在 layout 报了 unlinked-external。
(define (extern-symbols externs)
  (for/list ([row (in-list externs)]
             #:when (caddr row))
    (list 'symbol (cadr row) #f #f (caddr row))))

(define (collect-symbols segments anchors)
  (define start-of
    (for/hash ([seg (in-list segments)])
      (values (segment-field seg 'name) (segment-field seg 'start))))
  (for/list ([a (in-list anchors)])
    (define path (cadr a))
    (define seg (caddr a))
    (define off (cadddr a))
    (list 'symbol path seg off (+ (hash-ref start-of seg) off))))

(define (layout-symbols layout)
  (define hit (assoc 'symbols layout))
  (and hit (cdr hit)))

(define (symbol-row symbols path)
  (and path (findf (lambda (row) (equal? (cadr row) path)) symbols)))

;; ---------------------------------------------------------------------------
;; link 表: 对外的"名字 -> 绝对地址"
;;
;; symbol 行是 (symbol 链 段名 偏移 地址), 其中段名/偏移是**我自己的账**;
;; 对外能承诺的只有"这个名字在哪个地址"。所以 link 表就是两列投影:
;;
;;   (link (base B) (symbol 链 地址) ...)
;;
;; base = 这次布局用的镜像基址(spec 的 (origin …))。地址是“相对谁”的数,
;; 整体搬到别的地址时所有地址加 (新 base - base) —— 没有 base 就只是一个裸数。
;;
;; 行只来自 anchors, 所以**输出里不会出现未解析的行**; 输出可以直接当
;; 另一个镜像的输入用(缺口不随表传播)。
;;
;; 行只来自 anchors 加 provide 引入的别名, 所以**输出里不会出现未解析的行**;
;; 输出可以直接当另一个镜像的输入用(缺口不随表传播)。
;;
;; 两份输出必须可逐字节比较: 按地址升序, 同址按链的写法排序。

(define (make-link base rows)
  (cons 'link (cons (list 'base base) rows)))

(define (layout-link layout)
  (define hit (assoc 'link layout))
  (and hit (cdr hit)))

;; ---------------------------------------------------------------------------
;; provides: 对外承诺哪些名字
;;
;; `(provides 链 …)` —— 只有链，地址在 link 表里(同一张表, 别存两份)。
;; 顺序跟 link 表一致(按地址升序), 所以“按 provides 过滤 link”就是取子序列。
;;
;; exports 有两种取值(flatten 给的):
;;   'all     全单元没有 (provide …) 子句 -> 平铺镜像语义, 一切都导出
;;   (链 …)   各模块 provide 的并集(绝对链)
;;
;; 只认 link 表里真有的名字: flatten 已保证 provide 可解, 走到这里还缺说明
;; 输入不是 flatten 给的(或指到了别的镜像) —— 报 problem, 不抛异常。
;; ---------------------------------------------------------------------------

(define (chain-string chain) (format "~a" chain))

(define (link-row<? a b)
  (define x (list-ref a 2))
  (define y (list-ref b 2))
  (cond
    [(< x y) #t]
    [(> x y) #f]
    [else (string<? (chain-string (cadr a)) (chain-string (cadr b)))]))

;; symbol 行 (symbol 链 段名 偏移 地址) -> link 行 (symbol 链 地址)
(define (link-rows symbols)
  (sort (for/list ([row (in-list symbols)])
          (list 'symbol (cadr row) (last row)))
        link-row<?))

;; 返回 (values link 行 provides 链列表)
(define (exported rows exports problem!)
  (cond
    [(eq? exports 'all)
     (values rows (map cadr rows))]
    [else
     (define wanted (make-hash))
     (for ([c (in-list exports)]) (hash-set! wanted c #t))
     (for ([c (in-list exports)]
           #:unless (findf (lambda (r) (equal? (cadr r) c)) rows))
       (problem! `(provide-unknown ,c)))
     (values rows
             (for/list ([r (in-list rows)]
                        #:when (hash-ref wanted (cadr r) #f))
               (cadr r)))]))

(define (layout-provides layout)
  (define hit (assoc 'provides layout))
  (and hit (cdr hit)))

;; 绝对地址在最后一列
(define (symbol-address row) (last row))

(define (eval-symbol-address expr symbols)
  (eval-address
   expr
   (lambda (chain)
     (define row (symbol-row symbols chain))
     (and row (symbol-address row)))))

;; ---------------------------------------------------------------------------
;; 最终检查: 只有拿到最终地址/最终尺寸之后才有意义
;; ---------------------------------------------------------------------------

(define (fits-width? n width)
  (define bits (* 8 width))
  ;; 和 expand-data 同一条规则: 有符号或无符号能放进 bits 位即可
  (<= (- (expt 2 (sub1 bits))) n (sub1 (expt 2 bits))))

(define (all-chains-known? expr symbols)
  (andmap (lambda (c) (and (symbol-row symbols c) #t))
          (address-expr-chains expr)))

;; value 的值最终是否放得进宽度。
;;
;; 整数也查: expand-data 虽然查过, 但 data-items 也可以直接 seed 进来,
;; bind-labels 是最后一个能统一兜底的地方。
(define (check-value-widths segments symbols problem!)
  (for ([seg (in-list segments)])
    (define seg-name (segment-field seg 'name))
    (define items-hit (assoc 'items (cdr seg)))
    (for ([entry (in-list (if items-hit (cdr items-hit) '()))])
      (define off (cadr entry))
      (define it (caddr entry))
      (when (value-form? it)
        (define v (value-payload it))
        (define n
          (cond
            [(exact-integer? v) v]
            [(all-chains-known? v symbols) (eval-symbol-address v symbols)]
            [else #f]))
        (when (and n (not (fits-width? n (value-width it))))
          (problem! `(value-out-of-range ,seg-name ,off ,it ,n)))))))

(define (check-segment-overflow segments problem!)
  (for ([seg (in-list segments)])
    (define name (segment-field seg 'name))
    (define start (segment-field seg 'start))
    (define end (segment-field seg 'end))
    (define size (segment-field seg 'size))
    (define capacity (- end start))
    (when (and (>= capacity 0) (> size capacity))
      (problem! `(segment-overflow ,name ,size ,capacity)))))

;; ---------------------------------------------------------------------------
;; 入口
;; ---------------------------------------------------------------------------

(define (bound-layout? layout)
  (eq? (layout-phase layout) 'bound))

(define (bind-labels measured [exports 'all])
  (case (layout-phase measured)
    [(bound) measured]
    [(measured)
     (define segments (layout-segments measured))
     (define anchors (layout-anchors measured))
     ;; local-symbols: 本镜像里的 label(有段名/偏移); symbols: 再加外部符号。
     ;; 只有 local 进 link/provides —— 外部符号不是本镜像“提供”的东西。
     (define local-symbols (collect-symbols segments anchors))
     (define symbols (append local-symbols
                             (extern-symbols (or (layout-externs measured) '()))))
     (define origin (layout-origin measured))

     (define extra '())
     (define (problem! p) (set! extra (cons p extra)))
     (check-value-widths segments symbols problem!)
     (check-segment-overflow segments problem!)

     ;; link 表 = symbols 的两列投影 + provide 引入的别名(rename-out)
     (define-values (rows provided) (exported (link-rows local-symbols) exports problem!))
     (define link (make-link origin rows))

     (list (list 'phase 'bound)
           (list 'origin origin)
           (cons 'segments segments)
           (cons 'anchors anchors)
           (cons 'symbols symbols)
           ;; 对外接口: 名字 -> 地址; 顺序跟 provides 无关, 按地址升序
           link
           ;; 对外承诺哪些名字; 顺序跟 link 表一致, 地址不重复存
           (cons 'provides provided)
           (cons 'requests (layout-requests measured))
           (cons 'problems (append (layout-problems measured)
                                   (reverse extra))))]
    [else
     (error 'bind-labels
            "需要 measured-layout，拿到的是: ~e"
            (layout-phase measured))]))
