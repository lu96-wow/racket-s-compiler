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

(require "../sexp.rkt"
         (only-in "../layout/layout.rkt"
                  layout-phase layout-problems layout-requests
                  layout-segments layout-anchors)
         (only-in "../layout/forms.rkt"
                  value-form? value-width value-payload))

(provide bind-labels
         bound-layout?
         layout-symbols
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

(define (bind-labels measured)
  (case (layout-phase measured)
    [(bound) measured]
    [(measured)
     (define segments (layout-segments measured))
     (define anchors (layout-anchors measured))
     (define symbols (collect-symbols segments anchors))

     (define extra '())
     (define (problem! p) (set! extra (cons p extra)))
     (check-value-widths segments symbols problem!)
     (check-segment-overflow segments problem!)

     (list (list 'phase 'bound)
           (cons 'segments segments)
           (cons 'anchors anchors)
           (cons 'symbols symbols)
           (cons 'requests (layout-requests measured))
           (cons 'problems (append (layout-problems measured)
                                   (reverse extra))))]
    [else
     (error 'bind-labels
            "需要 measured-layout，拿到的是: ~e"
            (layout-phase measured))]))
