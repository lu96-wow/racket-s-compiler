#lang racket
;;; expand-data/expand.rkt
;;;
;;; 数据定义层: rich 数据 -> 核心数据 item。纯函数。
;;;
;;; 本层的输出词汇(只有这些):
;;;   (label 链...)                 位置
;;;   (bytes b...)                  已经定顺序的字节(字符串 / 人写的)
;;;   (fill 字节数 b)               b 重复 字节数 次(与端序无关)
;;;   (pad n)                       精确插 n 个字节(填什么由段 kind 定)
;;;   (value 宽度 值)               宽度个字节, 值的字节序还没定
;;;   (align n)                     对齐请求
;;;
;;; **端序不属于本层**: 它属于"变二进制"那一步(encode)。本层只交宽度 + 值。
;;;
;;; rich 形式(人写的):
;;;   (utf-string "…")               -> (bytes …UTF-8…)     ; 字节序列, 与端序无关
;;;   (utf-stringz "…")              -> (bytes …UTF-8… 0)
;;;   (b8 v) (b16 v) (b32 v) (b64 v) -> (value 1|2|4|8 v)
;;;   (bN-array 总数 v...)           -> (fill …) 或 n 条 (value …)
;;;
;;; 值有两种:
;;;   整数                    值域: v ∈ [-2^(8N-1), 2^(8N)), 按补码取低 8N 位
;;    (链) / (+ …) / (- …)          地址表达式（值推后）
;;; 地址表达式**不在这里求值**: 链的绝对地址要等布局(layout)才定, 字节要等 encode 才落。
;;; 所以本层只交出"宽度 + 值", 值和字节序都留给后面。
;;;
;;; 数组: (bN-array 总数 v...)
;;;   - 前 k 个位置用 v1..vk, 剩下的全用最后一个 vk
;;;   - 整个数组与端序无关(宽度 1, 或值全 0)时压成 (fill 字节数 b)
;;;     其余展开成 n 条 (value 宽度 v) —— 因为字节序还没定, 不能合并成 bytes
;;
;;; 只做数据定义: 宽度、值域、字节顺序、字符串、数组。
;;; 段、偏移、地址、代码都不属于本层; 下游怎么用本层不关心。
;;;
;;; 值域: v ∈ [-2^(8N-1), 2^(8N)), 按补码取低 8N 位。


(require "../sexp.rkt")

(provide expand-data
         expand-item
         as-items
         width-form?
         width-of)

;; ---------------------------------------------------------------------------
;; 基本形状
;; ---------------------------------------------------------------------------







(define (label-form? x)
  (and (form? x) (eq? (car x) 'label) (path? (cdr x))))

;; (module 名 item...) 是**结构壳**: 名字前缀/可见性是 flatten 的事, 本层不解释它,
;; 只是递归进去把数据展开, 壳原样留着。它的子句 (provide …) / (require …) 同理。
(define (module-form? x) (and (form? x) (eq? (car x) 'module)))
(define (module-clause? x) (and (form? x) (memq (car x) '(provide require))))

(define (byte? x) (and (exact-integer? x) (<= 0 x 255)))

(define (bytes-form? x)
  (and (form? x) (eq? (car x) 'bytes) (andmap byte? (cdr x))))

(define (align-form? x)
  (and (form? x) (eq? (car x) 'align) (= 2 (length x))
       (exact-positive-integer? (cadr x))))

;; (pad n): 精确插 n 个字节（填什么由段的 kind 决定，见 target.rkt 的填充策略）。
;; 和 (align n) 的区别: align 是"位置要对齐到 n"，补多少取决于当前地址；
;; pad 是"就插 n 字节"，与地址无关。名字归 layout，本层只透传。
(define (pad-item? x)
  (and (form? x) (eq? (car x) 'pad) (= 2 (length x))
       (exact-nonnegative-integer? (cadr x))))

;; (fill 字节数 b): b 重复 字节数 次。**名字归 layout**(padding 需要它), 本层只是生产者,
;; 所以这里的谓词不导出: 一个名字只能有一个归属。
(define (fill-item? x)
  (and (form? x) (eq? (car x) 'fill) (= 3 (length x))
       (exact-nonnegative-integer? (cadr x))
       (byte? (caddr x))))

;; ---------------------------------------------------------------------------
;; 宽度表
;; ---------------------------------------------------------------------------

(define width-forms '((b8 . 1) (b16 . 2) (b32 . 4) (b64 . 8)))
(define array-forms '((b8-array . 1) (b16-array . 2) (b32-array . 4) (b64-array . 8)))

(define (width-form? x)
  (and (form? x) (assq (car x) width-forms) (= 2 (length x))))

(define (width-of x) (cdr (assq (car x) width-forms)))

(define (array-form? x)
  (and (form? x) (assq (car x) array-forms)))

;; ---------------------------------------------------------------------------
;; 值: 整数, 或 label 地址表达式
;;
;;   值: 整数 | (链) | (+ 表达式 …) | (- 表达式 …)
;;   (+ (d t) 8)                 地址 + 8
;;   (- (d end) (d start))       两个 label 的差（长度/大小）
;;
;; 本层只检查形状, 不求值: 链的绝对地址要等布局(layout)才定, 字节要等 encode 才落。
;; ---------------------------------------------------------------------------

;; 整数: 值域检查, 原样返回
(define (check-value w v)
  (unless (exact-integer? v)
    (error 'expand-data "value must be an exact integer: ~e" v))
  (define bits (* 8 w))
  (define lo (- (expt 2 (sub1 bits))))
  (define hi (expt 2 bits))
  (unless (<= lo v (sub1 hi))
    (error 'expand-data "value ~a does not fit in ~a byte(s)" v w))
  v)

;; 一个值: 整数查值域, 地址表达式只查形状(求值是 layout / encode 的事)
(define (check-value-shape w v)
  (cond
    [(exact-integer? v) (check-value w v)]
    [(address-expr? v) v]
    [else (error 'expand-data "value must be an integer or an address expression: ~e" v)]))

;; 一个值 -> 一条 (value 宽度 值)。宽度是数据, 不是名字: 下游不用认识 b16。
;; 值可以是整数或地址表达式（rich 和 core 同形，原样透传）。
(define (value-item w v)
  (list 'value w (check-value-shape w v)))

;; (value 宽度 值) 也是核心形式: 透传(幂等)。名字归 layout(它要量宽度), 这里不导出。
;; 和 layout/forms.rkt 的 value-form? 是同一个形状; 本层只做透传, 所以不导出。
(define (value-form? x)
  (and (form? x) (eq? (car x) 'value) (= 3 (length x))
       (memq (cadr x) '(1 2 4 8))
       (address-expr? (caddr x))))

;; ---------------------------------------------------------------------------
;; 字符串
;; ---------------------------------------------------------------------------

(define (string-bytes s)
  (for/list ([b (in-bytes (string->bytes/utf-8 s))]) b))

(define (expand-string it)
  (unless (and (= 2 (length it)) (string? (cadr it)))
    (error 'expand-data "~a needs exactly one string: ~e" (car it) it))
  (define bs (string-bytes (cadr it)))
  (list (cons 'bytes (if (eq? (car it) 'utf-stringz)
                         (append bs (list 0))
                         bs))))

;; ---------------------------------------------------------------------------
;; item
;; ---------------------------------------------------------------------------

;; (bN-array 总数 v...) : 前 k 个用 v1..vk, 剩下的全用 vk
(define (check-array w it)
  (unless (>= (length it) 2)
    (error 'expand-data "array needs a size: ~e" it))
  (define size (cadr it))
  (define inits (cddr it))
  (unless (exact-nonnegative-integer? size)
    (error 'expand-data "array size must be a non-negative integer: ~e" it))
  (cond
    [(zero? size)
     (unless (null? inits)
       (error 'expand-data "array of size 0 cannot have init values: ~e" it))]
    [else
     (when (null? inits)
       (error 'expand-data "array needs at least one init value: ~e" it))
     (when (> (length inits) size)
       (error 'expand-data "more init values than the array size: ~e" it))
     (for ([v (in-list inits)]) (check-value-shape w v))])
  it)

;; (bN-array 总数 v...): 前 k 个用 v1..vk, 剩下全用 vk
;;
;; 端序没定, 所以只有"与端序无关"的数组能压成一条 fill:
;;   宽度 1        -> 任何值都是一个字节
;;   值全 0        -> 两种端序下都是全 0
;; 其余一个元素一条 (value 宽度 v)。地址数组也走这条路(每个元素一条)。
(define (expand-array w it)
  (define n (cadr it))
  (define inits (cddr it))
  (cond
    [(zero? n) (list (cons 'bytes '()))]
    [else
     (define lastv (last inits))
     ;; 与端序无关 = 宽度 1(一个元素就一个字节) 或值全 0
     (define same-tail? (and (exact-integer? lastv) (or (= 1 w) (zero? lastv))))
     (cond
       ;; 整个数组就是一个值, 且与端序无关 -> 一条 fill
       [(and (= 1 (length inits)) same-tail?)
        (list (list 'fill (* n w) (bitwise-and lastv #xFF)))]
       [else
        ;; 前 k 个逐条给; 尾部(都是 vk)在端序无关时压成 fill, 否则也逐条给
        (define tail-n (- n (length inits)))
        (append (for/list ([v (in-list inits)]) (value-item w v))
                (if (and same-tail? (positive? tail-n))
                    (list (list 'fill (* tail-n w) (bitwise-and lastv #xFF)))
                    (for/list ([_ (in-range tail-n)]) (value-item w lastv))))])]))

(define (expand-item it)
  (cond
    [(module-form? it)
     (unless (and (>= (length it) 2) (name? (cadr it)))
       (error 'expand-data "module needs a name: ~e" it))
     (list (cons 'module
                 (cons (cadr it)
                       (append* (for/list ([sub (in-list (cddr it))])
                                  (expand-item sub))))))]
    [(or (module-clause? it) (label-form? it)) (list it)]
    [(bytes-form? it) (list it)]
    [(fill-item? it) (list it)]
    [(pad-item? it) (list it)]
    [(value-form? it) (list it)]
    [(align-form? it) (list it)]
    [(width-form? it) (list (value-item (width-of it) (cadr it)))]
    [(array-form? it)
     (define w (cdr (assq (car it) array-forms)))
     (expand-array w (check-array w it))]
    [(and (form? it) (memq (car it) '(utf-string utf-stringz)))
     (expand-string it)]
    [else (error 'expand-data "unknown data form: ~e" it)]))

;; ---------------------------------------------------------------------------
;; 入口: 旧壳(quote/begin)也收, 出口是普通 item 列表
;; ---------------------------------------------------------------------------



(define (expand-data input)
  (append* (for/list ([it (in-list (as-items input))]) (expand-item it))))
