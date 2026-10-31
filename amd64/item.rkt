#lang racket
;;; amd64/item.rkt
;;;
;;; 程序/数据 item 的共享形状。这里只有形状，不含指令编码，也不含布局策略。
;;;
;;; layout 和 encode 都依赖这一层，避免 layout -> encode / encode -> layout。

(require "sexp.rkt")

(provide form? name? path? normalize-path
         label-form? label-chain
         align-form? pad-form? bytes-form? fill-form? value-form?
         value-width value-payload
         item-kind)

(define (label-form? x)
  (and (form? x) (eq? (car x) 'label) (path? (cdr x))))

(define (label-chain x) (cdr x))

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

(define (value-width x) (cadr x))
(define (value-payload x) (caddr x))

(define (value-form? x)
  (and (form? x) (eq? (car x) 'value) (= 3 (length x))
       (memq (value-width x) '(1 2 4 8))))

(define (item-kind x)
  (cond
    [(label-form? x) 'marker]
    [(or (align-form? x) (pad-form? x)) 'both]
    [(or (bytes-form? x) (fill-form? x) (value-form? x)) 'data]
    [else 'code]))
