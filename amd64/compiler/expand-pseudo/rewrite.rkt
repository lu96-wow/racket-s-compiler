#lang racket
;;; amd64/compiler/expand-pseudo/rewrite.rkt
;;;
;;; 把源码写法规范化成 amd64 encode 认识的 form。
;;;
;;; 只做拼写/分支形式的选择，不判断指令是否可编码，也不解析标签。
;;; 操作数是值，不递归改写。

(require "../../amd64-asm/sexp.rkt"
         "../../amd64-help/main.rkt")

(provide rewrite-item
         rewrite-program
         pseudo-name?
         pseudo-leftover?
         as-items)

;; ---------------------------------------------------------------------------
;; 条件码别名
;; ---------------------------------------------------------------------------

(define (pseudo-name? h)
  (and (symbol? h)
       (or (jcc-alias? h)
           (memq h '(jmp jcc call li)))))

;; ---------------------------------------------------------------------------
;; 分支形式
;; ---------------------------------------------------------------------------

(define (rewrite-item item #:short-transfers? [short? #f])
  (cond
    [(not (form? item)) item]
    [else
     (define h (car item))
     (case h
       [(jmp)
        (match item
          [(list 'jmp target) (jump-form target short?)]
          [_ item])]
       [(jcc)
        (match item
          [(list 'jcc cc target) (branch-form cc target short?)]
          [_ item])]
       [(call)
        (match item
          [(list 'call target) (call-form target)]
          [_ item])]
       [(li)
        (match item
          [(list 'li dst value) (li->form dst value)]
          [_ item])]
       [else
        (cond
          [(canonical-cc h)
           => (lambda (cc)
                (match item
                  [(list _ target) (branch-form cc target short?)]
                  [_ item]))]
          [else item])])]))

(define (rewrite-program items #:short-transfers? [short? #f])
  (map (lambda (item) (rewrite-item item #:short-transfers? short?))
       (as-items items)))

(define (pseudo-leftover? x)
  (define (walk i)
    (and (form? i)
         (let ([h (car i)])
           (or (pseudo-name? h)
               (jcc-alias? h)))))
  (define items
    (cond
      [(and (form? x) (symbol? (car x))) (list x)]
      [else (as-items x)]))
  (for/or ([i (in-list items)]) (and (walk i) #t)))
