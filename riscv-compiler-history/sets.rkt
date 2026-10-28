#lang racket/base

;; ============================================================
;; 集合工具
;;
;; 集合统一用排序后的 symbol list 表示，方便打印和比较。
;; ============================================================

(require racket/list)

(provide sort-set
         set-member?
         set-union
         set-subtract
         set=?
         set-empty?)

(define (sort-set values)
  (sort (remove-duplicates values eq?) symbol<?))

(define (set-member? value set)
  (and (memq value set) #t))

(define (set-union a b)
  (sort-set (append a b)))

(define (set-subtract a b)
  (sort-set (filter (lambda (value) (not (memq value b))) a)))

(define (set=? a b)
  (equal? (sort-set a) (sort-set b)))

(define (set-empty? set)
  (null? set))
