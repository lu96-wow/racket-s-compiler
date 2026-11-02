#lang racket
;;; amd64/compiler/problem.rkt
;;;
;;; 流水线里的 "problem" 只有一种形状：
;;;
;;;   (种类 细节 ...)         例如 (unplaced-block (code 3) ((text)))
;;;
;;; 每层负责收集自己发现的问题, 由入口层决定是报错还是继续(验证工具会打印
;;; 它们); 种类是 car, 细节是 cdr。不要各层自己拼形状 —— 下游不认识第二份。
;;;
;;; 注：loko-compat 内部用记录(struct loko-problem)先装, 是因为它的输出
;;; 里也有 label 名字, 不能拿"car 是符号的 list"当问题判据; 它在边界上
;;; 用这里的形状吐出来。

(provide make-problem
         problem?
         problem-kind
         problem-detail)

(define (make-problem kind . detail)
  (unless (symbol? kind)
    (error 'make-problem "problem kind must be a symbol: ~e" kind))
  (cons kind detail))

(define (problem? x)
  (and (pair? x) (symbol? (car x)) #t))

(define (problem-kind x) (car x))
(define (problem-detail x) (cdr x))
