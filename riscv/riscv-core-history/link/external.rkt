#lang racket
;;; link/external.rkt
;;;
;;; 外部符号和地址数据。它们不属于 core IR。
;;;
;;; 形状：
;;;   (extern chain (kind kind))
;;;   (address chain value)
;;;
;;; kind:
;;;   func | data | raw | raw-label | data-label
;;;
;;; 地址数据只在 link 阶段使用。

(require racket/list
         "../core/sexp.rkt")

(provide extern-form?
         extern-name
         extern-kind
         extern-kind?
         address-form?
         address-name
         address-value
         extern-call-kind?
         extern-address-kind?
         extern-table)

(define extern-kinds
  '(func data raw raw-label data-label))

(define (extern-kind? x)
  (and (symbol? x) (and (memq x extern-kinds) #t)))

(define (extern-form? x)
  (match x
    [(list 'extern (? chain? name) (list 'kind (? extern-kind? kind))) #t]
    [_ #f]))

(define (extern-name x)
  (unless (extern-form? x)
    (error 'external "malformed extern: ~e" x))
  (cadr x))

(define (extern-kind x)
  (unless (extern-form? x)
    (error 'external "malformed extern: ~e" x))
  (cadr (caddr x)))

(define (extern-call-kind? kind)
  (eq? kind 'func))

(define (extern-address-kind? kind)
  (and (memq kind '(func data raw raw-label data-label)) #t))

(define (address-form? x)
  (match x
    [(list 'address (? chain? name) (? exact-integer? value)) #t]
    [_ #f]))

(define (address-name x)
  (unless (address-form? x)
    (error 'external "malformed address: ~e" x))
  (cadr x))

(define (address-value x)
  (unless (address-form? x)
    (error 'external "malformed address: ~e" x))
  (caddr x))

;; extern 列表 -> hash chain -> kind
(define (extern-table externs)
  (define table (make-hash))
  (for ([e (in-list externs)])
    (unless (extern-form? e)
      (error 'external "malformed extern: ~e" e))
    (define name (extern-name e))
    (when (hash-has-key? table name)
      (error 'external "extern ~a is defined twice" (chain->string name)))
    (hash-set! table name (extern-kind e)))
  table)
