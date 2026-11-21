#lang racket
;;; core/sexp.rkt
;;;
;;; 跨层共享的 s-exp 形状。这里没有模块语义，也没有 virtual IR 语义。
;;;
;;; 只有：
;;;   - 什么算 form / name / chain / tagged form；
;;;   - 带 tag 的 operand：($ name) / (native xN) / (global chain)；
;;;   - 链的比较和格式化。
;;;
;;; 全部用 list / symbol 操作，不做字符串前缀解析。
;;; 字符串只用于排序和错误消息。

(provide form?
         name?
         chain?
         tagged?
         chain<?
         chain->string
         vreg?
         native?
         global-ref?)

;; 真列表（代码/数据形式的形状）。'() 和 dotted pair 都不是 form。
(define (form? x)
  (and (pair? x) (list? x)))

;; 名字是 symbol。
(define (name? x)
  (symbol? x))

;; 非空 symbol 列表。
(define (chain? x)
  (and (form? x) (andmap name? x)))

(define (tagged? x tag)
  (and (form? x) (eq? (car x) tag)))

;; 只用于确定性排序；不是名字解析。
(define (chain<? a b)
  (let loop ([a a] [b b])
    (cond
      [(null? a) (pair? b)]
      [(null? b) #f]
      [else
       (define sa (symbol->string (car a)))
       (define sb (symbol->string (car b)))
       (cond
         [(string<? sa sb) #t]
         [(string>? sa sb) #f]
         [else (loop (cdr a) (cdr b))])])))

;; 只用于错误消息。
(define (chain->string chain)
  (string-join (map symbol->string chain) " "))

;; 带 tag 的操作数。shape 只在 tag 和链上，不做类型推断。
(define (vreg? x)
  (match x
    [(list '$ (? name? _)) #t]
    [_ #f]))

(define (native? x)
  (match x
    [(list 'native (? name? _)) #t]
    [_ #f]))

(define (global-ref? x)
  (match x
    [(list 'global (? chain? _)) #t]
    [_ #f]))
