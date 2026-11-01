#lang racket
;;; amd64/compiler/item.rkt
;;;
;;; 程序/数据 item 的共享形状。这里只有形状，不含指令编码，也不含布局策略。
;;; item: (label …) (comment …) (bytes …) (fill …) (pad …) (align …)
;;;       (value …) (reserve n) 或指令。
;;;
;;; layout 和 encode 都依赖这一层，避免 layout -> encode / encode -> layout。

(require "../amd64-asm/sexp.rkt")

(provide form? name? path? normalize-path
         make-label make-comment
         make-align make-pad make-bytes-item make-fill make-value make-reserve
         label-form? label-chain
         comment-form?
         align-form? align-value
         pad-form? pad-size
         bytes-form? bytes-content
         fill-form? fill-size fill-byte
         value-form? value-width value-payload
         reserve-form? reserve-size
         item-kind)

;; ---------------------------------------------------------------------------
;; Constructors (single source of canonical item shapes)
;; ---------------------------------------------------------------------------

(define (make-label chain)
  (define path (normalize-path chain))
  (unless path
    (error 'make-label "label needs a non-empty name chain: ~e" chain))
  (cons 'label path))

(define (make-comment . data)
  (cons 'comment data))

(define (make-align n)
  (unless (exact-positive-integer? n)
    (error 'make-align "alignment must be a positive integer: ~e" n))
  (list 'align n))

(define (make-pad n)
  (unless (exact-nonnegative-integer? n)
    (error 'make-pad "pad size must be a non-negative integer: ~e" n))
  (list 'pad n))

(define (make-bytes-item bs)
  (unless (and (list? bs) (andmap byte? bs))
    (error 'make-bytes-item "bytes must be a list of 0..255: ~e" bs))
  (cons 'bytes bs))

(define (make-fill n b)
  (unless (exact-nonnegative-integer? n)
    (error 'make-fill "fill count must be a non-negative integer: ~e" n))
  (unless (byte? b)
    (error 'make-fill "fill byte must be 0..255: ~e" b))
  (list 'fill n b))

(define (make-value width payload)
  (unless (memq width '(1 2 4 8))
    (error 'make-value "value width must be 1/2/4/8: ~e" width))
  (unless (address-expr? payload)
    (error 'make-value "value must be an integer or address expression: ~e"
           payload))
  (list 'value width payload))

(define (make-reserve n)
  (unless (exact-nonnegative-integer? n)
    (error 'make-reserve "reserve size must be a non-negative integer: ~e" n))
  (list 'reserve n))

(define (label-form? x)
  (and (form? x) (eq? (car x) 'label) (path? (cdr x))))

(define (label-chain x) (cdr x))

;; (comment datum ...) 是零尺寸注记：给后面的层留事实（Loko 用 %comment
;; 记录 liveness），但不产生字节。
(define (comment-form? x)
  (and (form? x) (eq? (car x) 'comment)))

(define (align-form? x)
  (and (form? x) (eq? (car x) 'align) (= 2 (length x))
       (exact-positive-integer? (cadr x))))

(define (pad-form? x)
  (and (form? x) (eq? (car x) 'pad) (= 2 (length x))
       (exact-nonnegative-integer? (cadr x))))

(define (byte? x) (and (exact-integer? x) (<= 0 x 255)))

(define (bytes-form? x)
  (and (form? x) (eq? (car x) 'bytes) (andmap byte? (cdr x))))

(define (fill-form? x)
  (and (form? x) (eq? (car x) 'fill) (= 3 (length x))
       (exact-nonnegative-integer? (cadr x)) (byte? (caddr x))))

(define (reserve-form? x)
  (and (form? x) (eq? (car x) 'reserve) (= 2 (length x))
       (exact-nonnegative-integer? (cadr x))))

(define (align-value x) (cadr x))
(define (pad-size x) (cadr x))
(define (bytes-content x) (cdr x))
(define (fill-size x) (cadr x))
(define (fill-byte x) (caddr x))
(define (reserve-size x) (cadr x))

(define (value-width x) (cadr x))
(define (value-payload x) (caddr x))

(define (value-form? x)
  (and (form? x) (eq? (car x) 'value) (= 3 (length x))
       (memq (value-width x) '(1 2 4 8)) #t))

;; item 的类别: 决定它能落进哪种段 (合法性表在 layout/forms.rkt)。
;;   marker       = label / comment, 不占字节, 三种段都行
;;   align        = align(请求), 补出来的是 pad 还是 reserve 由段 kind 定
;;   pad          = pad(事实) = 补 n 个字节, 要材料化
;;   space        = reserve, 只推进位置, 只有 hole 段收
;;   materialized = bytes / fill / value, 要写字节
;;   code         = 指令
;; 这里只回答"这条 item 是什么", 不回答"它能不能放进某段"。
(define (item-kind x)
  (cond
    [(or (label-form? x) (comment-form? x)) 'marker]
    [(align-form? x) 'align]
    [(pad-form? x) 'pad]
    [(reserve-form? x) 'space]
    [(or (bytes-form? x) (fill-form? x) (value-form? x)) 'materialized]
    [else 'code]))
