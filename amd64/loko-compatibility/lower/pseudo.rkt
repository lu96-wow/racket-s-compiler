#lang racket
;;; amd64/loko-compatibility/lower/pseudo.rkt
;;;
;;; Loko 的伪寄存器 (reg N) 的共享形状和替换。
;;;
;;; 这里只认识形状，不做分配：
;;;
;;;   (reg 0)       伪寄存器，N 是非负整数
;;;
;;; allocate.rkt 决定 N -> 物理寄存器；本文件负责在 item 树里找到/替换它们。
;;; 除了 (reg N) 本身，替换会进入内存操作数的 disp 表达式和嵌套 form。

(require "../../amd64-asm/sexp.rkt")

(provide pseudo-register?
         pseudo-register-index
         make-pseudo-register
         pseudo-registers-in
         substitute-pseudo-registers
         allocation-ref
         allocation-pair-value)

(define (pseudo-register? x)
  (and (form? x)
       (eq? (car x) 'reg)
       (= 2 (length x))
       (exact-nonnegative-integer? (cadr x))
       #t))

(define (pseudo-register-index x)
  (unless (pseudo-register? x)
    (error 'pseudo-register-index "not a pseudo register: ~e" x))
  (cadr x))

(define (make-pseudo-register n)
  (unless (exact-nonnegative-integer? n)
    (error 'make-pseudo-register "bad pseudo register index: ~e" n))
  (list 'reg n))

;; ---------------------------------------------------------------------------
;; 查找
;; ---------------------------------------------------------------------------

;; 遍历一个 item/表达式，按出现顺序返回伪寄存器下标（去重）。
(define (pseudo-registers-in x)
  (define seen (make-hash))
  (define out '())
  (let walk ([x x])
    (cond
      [(pseudo-register? x)
       (define n (pseudo-register-index x))
       (unless (hash-ref seen n #f)
         (hash-set! seen n #t)
         (set! out (cons n out)))]
      [(pair? x)
       (walk (car x))
       (walk (cdr x))]
      [else (void)]))
  (reverse out))

;; ---------------------------------------------------------------------------
;; 替换
;; ---------------------------------------------------------------------------

;; allocation 是 hash 或 alist：伪寄存器下标 -> 物理寄存器名。
;; alist 的每一项可以写成点对 (0 . rax)，也可以写成 (0 rax)。
(define (allocation-pair-value p)
  (if (and (list? p) (= 2 (length p)))
      (cadr p)
      (cdr p)))

(define (allocation-ref allocation n)
  (cond
    [(hash? allocation) (hash-ref allocation n #f)]
    [(list? allocation)
     (define p (assq n allocation))
     (and p (allocation-pair-value p))]
    [else
     (error 'allocation-ref "allocation must be a hash or alist: ~e" allocation)]))

;; 返回 (values 新 item 缺失的伪寄存器下标表)。
;; 没有分配的伪寄存器保持原样；调用方决定这是不是错误。
(define (substitute-pseudo-registers x allocation)
  (define missing (make-hash))
  (define (subst x)
    (cond
      [(pseudo-register? x)
       (define n (pseudo-register-index x))
       (cond
         [(allocation-ref allocation n)]
         [else
          (hash-set! missing n #t)
          x])]
      [(pair? x) (cons (subst (car x)) (subst (cdr x)))]
      [else x]))
  (values (subst x) (sort (hash-keys missing) <)))
