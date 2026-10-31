#lang racket
;;; amd64/expand-pseudo/rewrite.rkt
;;;
;;; 把源码写法规范化成 amd64 encode 认识的 form。
;;;
;;; 只做拼写/分支形式的选择，不判断指令是否可编码，也不解析标签。
;;; 操作数是值，不递归改写。

(require "../sexp.rkt")

(provide rewrite-item
         rewrite-program
         pseudo-name?
         pseudo-leftover?
         as-items)

;; ---------------------------------------------------------------------------
;; 条件码别名
;; ---------------------------------------------------------------------------

(define jcc-alias
  (hash
   'je 'e   'jz 'e
   'jne 'ne 'jnz 'ne
   'jc 'b   'jnae 'b
   'jnc 'ae 'jnb 'ae 'jae 'ae
   'jbe 'be 'jna 'be
   'ja 'a   'jnbe 'a
   'js 's   'jns 'ns
   'jp 'p   'jpe 'p
   'jnp 'np 'jpo 'np
   'jl 'l   'jnge 'l
   'jge 'ge 'jnl 'ge
   'jle 'le 'jng 'le
   'jg 'g   'jnle 'g
   'jo 'o   'jno 'no))

(define (pseudo-name? h)
  (and (symbol? h)
       (or (hash-has-key? jcc-alias h)
           (memq h '(jmp jcc call li)))))

;; ---------------------------------------------------------------------------
;; 分支形式
;; ---------------------------------------------------------------------------

(define (jump-form target short?)
  (if short? (list 'jmp-short target) (list 'jmp-near target)))

(define (branch-form cc target short?)
  (if short? (list 'jcc-short cc target) (list 'jcc-near cc target)))

(define (rewrite-item item #:short-branches? [short? #f])
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
          [(list 'call target) (list 'call-near target)]
          [_ item])]
       [(li)
        (match item
          [(list 'li dst value) (list 'mov dst value)]
          [_ item])]
       [else
        (cond
          [(hash-ref jcc-alias h #f)
           (match item
             [(list _ target) (branch-form (hash-ref jcc-alias h) target short?)]
             [_ item])]
          [else item])])]))

(define (rewrite-program items #:short-branches? [short? #f])
  (map (lambda (item) (rewrite-item item #:short-branches? short?))
       (as-items items)))

(define (pseudo-leftover? x)
  (define (walk i)
    (and (form? i)
         (let ([h (car i)])
           (or (pseudo-name? h)
               (hash-has-key? jcc-alias h)))))
  (define items
    (cond
      [(and (form? x) (symbol? (car x))) (list x)]
      [else (as-items x)]))
  (for/or ([i (in-list items)]) (and (walk i) #t)))
