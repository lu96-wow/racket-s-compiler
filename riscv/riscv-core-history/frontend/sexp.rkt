#lang racket
;;; frontend/sexp.rkt
;;;
;;; 前端自己的形状：file / module / provide / require / func / data / raw，
;;; 以及 raw 里“哪个操作数是全局 label”的位置表。
;;;
;;; 通用形状（form / name / chain / vreg / native / global）在 core/sexp.rkt。
;;; 这里 re-provide 它们，前端代码只需要 require 本文件。

(require "../core/sexp.rkt")

(provide (all-from-out "../core/sexp.rkt")
         source-name?
         file-form?
         module-form?
         provide-form?
         require-form?
         func-form?
         data-form?
         raw-form?
         label-form?
         raw-label-operand-index)

;; 文件标签里的名字只用于错误消息，不进入核心 IR。
(define (source-name? x)
  (or (symbol? x) (string? x)))

(define (file-form? x) (tagged? x 'file))
(define (module-form? x) (tagged? x 'module))
(define (provide-form? x) (tagged? x 'provide))
(define (require-form? x) (tagged? x 'require))
(define (func-form? x) (tagged? x 'func))
(define (data-form? x) (tagged? x 'data))
(define (raw-form? x) (tagged? x 'raw))

;; (label chain ...) 至少有一个链。
(define (label-form? x)
  (and (tagged? x 'label)
       (pair? (cdr x))
       (andmap chain? (cdr x))))

;; raw 是 machine 层，前端只关心“哪个位置是全局 label”。
;; native 目标在前：分支 / j / call / tail 的目标在第一个操作数；
;; jal 的 native 顺序是 (jal rd jimm20)，目标在第二个操作数。
;; 这里不是编码表，只是 raw 名字位置表。
(define raw-label-operand-index-table
  (hash 'j 0
        'jal 1
        'beq 0
        'bne 0
        'blt 0
        'bge 0
        'bltu 0
        'bgeu 0
        'beqz 0
        'bnez 0
        'ble 0
        'bgt 0
        'c.j 0
        'c.jal 0
        'c.beqz 1
        'c.bnez 1
        'call 0
        'tail 0))

(define (raw-label-operand-index head)
  (hash-ref raw-label-operand-index-table head #f))
