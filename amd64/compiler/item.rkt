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
         label-form? label-chain
         comment-form?
         align-form? pad-form? bytes-form? fill-form? value-form?
         reserve-form? reserve-size
         value-width value-payload
         item-kind)

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

(define (reserve-size x) (cadr x))

(define (value-width x) (cadr x))
(define (value-payload x) (caddr x))

(define (value-form? x)
  (and (form? x) (eq? (car x) 'value) (= 3 (length x))
       (memq (value-width x) '(1 2 4 8))))

(define (item-kind x)
  (cond
    [(or (label-form? x) (comment-form? x)) 'marker]
    [(or (align-form? x) (pad-form? x)) 'both]
    [(or (bytes-form? x) (fill-form? x) (value-form? x) (reserve-form? x)) 'data]
    [else 'code]))
