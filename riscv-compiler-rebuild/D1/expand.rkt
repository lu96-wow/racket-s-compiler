#lang racket
;;; D1/expand.rkt
;;;
;;; 数据定义层: rich 数据 -> 核心数据 item。纯函数。
;;;
;;; 本层的输出词汇(只有这些):
;;;   (label 链...)                 位置
;;;   (bytes b...)                  已经定顺序的字节(字符串 / 人写的)
;;;   (fill 字节数 b)               b 重复 字节数 次(与端序无关)
;;;   (value 宽度 值)               宽度个字节, 值的字节序还没定
;;;   (align n)                     对齐请求
;;;
;;; **端序不属于本层**: 它属于"变二进制"那一步(L7)。本层只交宽度 + 值。
;;;
;;; rich 形式(人写的):
;;;   (utf-string "…")               -> (bytes …UTF-8…)     ; 字节序列, 与端序无关
;;;   (utf-stringz "…")              -> (bytes …UTF-8… 0)
;;;   (b8 v) (b16 v) (b32 v) (b64 v) -> (value 1|2|4|8 v)
;;;   (bN-array 总数 v...)           -> (fill …) 或 n 条 (value …)
;;;
;;; 值有两种:
;;;   整数                    值域: v ∈ [-2^(8N-1), 2^(8N)), 按补码取低 8N 位
;;;   (label+ 链 [加数])      地址 + 加数
;;;   (label- 链 [加数])      地址 - 加数  -> 归一成 (label+ 链 -加数)
;;; 地址表达式**不在这里求值**: 链的绝对地址要等布局(L5)才定, 字节要等 L7 才落。
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
;;; label+ / label- 暂不支持: 遇到就报错。

(provide expand-data
         expand-item
         program-items
         width-form?
         width-of)

;; ---------------------------------------------------------------------------
;; 基本形状
;; ---------------------------------------------------------------------------

(define (form? x) (and (pair? x) (list? x)))

(define (name? x) (or (symbol? x) (string? x) (number? x)))

(define (path? x) (and (list? x) (pair? x) (andmap name? x)))

(define (label-form? x)
  (and (form? x) (eq? (car x) 'label) (path? (cdr x))))

(define (byte? x) (and (exact-integer? x) (<= 0 x 255)))

(define (bytes-form? x)
  (and (form? x) (eq? (car x) 'bytes) (andmap byte? (cdr x))))

(define (align-form? x)
  (and (form? x) (eq? (car x) 'align) (= 2 (length x))
       (exact-positive-integer? (cadr x))))

;; (fill 字节数 b): b 重复 字节数 次。**名字归 L5**(padding 需要它), 本层只是生产者,
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
;;   (label+ 链)        地址
;;   (label+ 链 加数)   地址 + 加数
;;   (label- 链 加数)   地址 - 加数
;;
;; 本层只检查形状, 不求值: 链的绝对地址要等布局(L5)才定, 字节要等 L7 才落。
;; ---------------------------------------------------------------------------

(define (label-expr? v)
  (and (form? v)
       (memq (car v) '(label+ label-))
       (let ([args (cdr v)])
         (and (memq (length args) '(1 2))
              (path? (car args))
              (or (= 1 (length args)) (exact-integer? (cadr args)))))))

;; 归一: (label- 链 n) => (label+ 链 -n); 加数一定写出来(字段固定)
(define (normalize-label-expr v)
  (define a (if (= 3 (length v)) (caddr v) 0))
  (list 'label+ (cadr v) (if (eq? (car v) 'label-) (- a) a)))

;; 整数: 值域检查, 原样返回
(define (check-value w v)
  (unless (exact-integer? v)
    (error 'D1 "value must be an exact integer or a label expression: ~e" v))
  (define bits (* 8 w))
  (define lo (- (expt 2 (sub1 bits))))
  (define hi (expt 2 bits))
  (unless (<= lo v (sub1 hi))
    (error 'D1 "value ~a does not fit in ~a byte(s)" v w))
  v)

;; 一个值 -> 一条 (value 宽度 值)。宽度是数据, 不是名字: 下游不用认识 b16。
(define (value-item w v)
  (list 'value w
        (if (label-expr? v)
            (normalize-label-expr v)
            (check-value w v))))

;; (value 宽度 值) 也是核心形式: 透传(幂等)。名字归 L5(它要量宽度), 这里不导出。
(define (value-item? x)
  (and (form? x) (eq? (car x) 'value) (= 3 (length x))
       (memq (cadr x) '(1 2 4 8))
       (or (exact-integer? (caddr x)) (label-expr? (caddr x)))))

;; ---------------------------------------------------------------------------
;; 字符串
;; ---------------------------------------------------------------------------

(define (string-bytes s)
  (for/list ([b (in-bytes (string->bytes/utf-8 s))]) b))

(define (expand-string it)
  (unless (and (= 2 (length it)) (string? (cadr it)))
    (error 'D1 "~a needs exactly one string: ~e" (car it) it))
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
    (error 'D1 "array needs a size: ~e" it))
  (define size (cadr it))
  (define inits (cddr it))
  (unless (exact-nonnegative-integer? size)
    (error 'D1 "array size must be a non-negative integer: ~e" it))
  (cond
    [(zero? size)
     (unless (null? inits)
       (error 'D1 "array of size 0 cannot have init values: ~e" it))]
    [else
     (when (null? inits)
       (error 'D1 "array needs at least one init value: ~e" it))
     (when (> (length inits) size)
       (error 'D1 "more init values than the array size: ~e" it))
     (for ([v (in-list inits)])
       (unless (label-expr? v) (check-value w v)))])
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
    [(label-form? it) (list it)]
    [(bytes-form? it) (list it)]
    [(fill-item? it) (list it)]
    [(value-item? it) (list it)]
    [(align-form? it) (list it)]
    [(width-form? it) (list (value-item (width-of it) (cadr it)))]
    [(array-form? it)
     (define w (cdr (assq (car it) array-forms)))
     (expand-array w (check-array w it))]
    [(and (form? it) (memq (car it) '(utf-string utf-stringz)))
     (expand-string it)]
    [else (error 'D1 "unknown data form: ~e" it)]))

;; ---------------------------------------------------------------------------
;; 入口: 旧壳(quote/begin)也收, 出口是普通 item 列表
;; ---------------------------------------------------------------------------

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
      [(pair? (car body)) body]
      [else (list body)]))
  (if (and (= 1 (length items)) (form? (car items)) (eq? (caar items) 'begin))
      (cdar items)
      items))

(define (expand-data input)
  (append* (for/list ([it (in-list (program-items input))]) (expand-item it))))
