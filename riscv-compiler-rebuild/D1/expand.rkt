#lang racket
;;; D1/expand.rkt
;;;
;;; 数据定义层: rich 数据 -> 核心数据 item。纯函数。
;;;
;;; 本层的输出词汇(只有这些):
;;;   (label 链...)                 位置
;;;   (bytes b...)                  已经定顺序的字面字节
;;;   (b8 v) (b16 v) (b32 v) (b64 v)  宽度 + 整数值
;;;   (b8-array 总数 v...) …          宽度 + 总数 + 初始化值
;;;   (align n)                     对齐请求
;;;
;;; rich 形式(人写的):
;;;   (utf-string "…")               -> (bytes …UTF-8…)
;;;   (utf-stringz "…")              -> (bytes …UTF-8… 0)
;;;
;;; 数组: (bN-array 总数 v...)
;;;   - 前 k 个位置用 v1..vk, 剩下的全用最后一个 vk
;;;   - 不展开成长列表: (b8-array 4096 0) 还是一条 item
;;;
;; 只做数据定义: 宽度、值域、字符串、数组。
;;; 段、偏移、地址、端序、代码都不属于本层; 下游怎么用本层不关心。
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
;; 值: 只收整数; 地址表达式(label+ / label-)未实现
;; ---------------------------------------------------------------------------

(define (check-value w v)
  (when (form? v)
    (error 'D1 "address expressions (label+ / label-) are not implemented yet: ~e" v))
  (unless (exact-integer? v)
    (error 'D1 "value must be an exact integer: ~e" v))
  (define bits (* 8 w))
  (define lo (- (expt 2 (sub1 bits))))
  (define hi (expt 2 bits))
  (unless (<= lo v (sub1 hi))
    (error 'D1 "value ~a does not fit in ~a byte(s)" v w))
  v)

(define (width-head w)
  (case w
    [(1) 'b8]
    [(2) 'b16]
    [(4) 'b32]
    [(8) 'b64]
    [else (error 'D1 "bad width: ~a" w)]))

(define (width-item w v)
  (list (width-head w) (check-value w v)))

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
     (for ([v (in-list inits)]) (check-value w v))])
  it)

(define (expand-item it)
  (cond
    [(label-form? it) (list it)]
    [(bytes-form? it) (list it)]
    [(align-form? it) (list it)]
    [(width-form? it) (list (width-item (width-of it) (cadr it)))]
    [(array-form? it)
     (define w (cdr (assq (car it) array-forms)))
     (list (check-array w it))]
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
