#lang racket/base

;;; meta.rkt
;;;
;;; 带标签 s-exp 元数据的公共读取器。
;;;
;;; 很多层都长这样：
;;;
;;;   (symbol 链 地址)
;;;   (field (name x) (type b32) (offset 0) ...)
;;;   (segment (name c) (kind code) ...)
;;;
;;; 以前每层都写一遍 (assoc tag (cdr form)) + 长度检查。这里只保留这一种做法。

(require "sexp.rkt")

(provide tagged-form?
         tag-ref
         tag-ref*)

(define (tagged-form? x tag)
  (and (form? x) (eq? (car x) tag)))

;; (tag-ref who form 'name) -> form 里 (name 值) 的值
(define (tag-ref who form tag)
  (define row (and (form? form) (assq tag (cdr form))))
  (unless (and row (= 2 (length row)))
    (error who "~a 需要 (~a 值): ~e" who tag form))
  (cadr row))

(define (tag-ref* who form tag default)
  (define row (and (form? form) (assq tag (cdr form))))
  (if (and row (= 2 (length row)))
      (cadr row)
      default))
