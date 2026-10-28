#lang racket
;;; flatten-test.rkt -- 模块系统 + 链式查表
;;;
;;; 契约: 只改名字。输出里所有 label 和引用都是完整链, 模块壳被消费掉。

(require rackunit
         "helpers.rkt"
         (only-in "../riscv-compiler-rebuild/flatten/flatten.rkt"
                  flatten-program flatten-inputs flatten-items))

(define (flat x) (flatten-program x))

;; ---------------------------------------------------------------------------
;; 嵌套 / 完整链 / 多名字
;; ---------------------------------------------------------------------------

(check-equal? (flat '((label root) (jal x0 (root))))
              '((label root) (jal x0 (root))))

(check-equal? (flat '((module a (label f) (jal x0 (f)))))
              '((label a f) (jal x0 (a f))))

(check-equal? (flat '((module a (module b (label f) (jal x0 (f))))))
              '((label a b f) (jal x0 (a b f))))

;; 内层遮蔽外层
(check-equal? (flat '((label h) (jal x0 (h))
                      (module a (label h) (jal x0 (h)))))
              '((label h) (jal x0 (h))
                (label a h) (jal x0 (a h))))

;; 同一位置连续多条 label = 多个名字
(check-equal? (flat '((label a f) (label a g) (jal x0 (a g))))
              '((label a f) (label a g) (jal x0 (a g))))

;; 子模块可见祖先模块的 label
(check-equal? (flat '((module a
                       (label f)
                       (module b (jal x0 (f))))))
              '((label a f) (jal x0 (a f))))

;; 只重写链; 寄存器 / 立即数 / 裸原子不动
(check-equal? (flat '((label f)
                      (add t0 t1 42)
                      (lw t0 t1 8)
                      (jal x0 t0)))
              '((label f) (add t0 t1 42) (lw t0 t1 8) (jal x0 t0)))

;; 地址表达式里的每条链都重写
(check-equal? (flat '((label f) (label g)
                      (b64 (+ (f) 8))
                      (b32 (- (g) (f)))
                      (b64 (+ (- (g) (f)) 4))))
              '((label f) (label g)
                (b64 (+ (f) 8))
                (b32 (- (g) (f)))
                (b64 (+ (- (g) (f)) 4))))

;; ---------------------------------------------------------------------------
;; provide / require
;; ---------------------------------------------------------------------------

(check-equal? (flat '((module a (provide f) (label f))
                      (module b (require a) (la t0 (f)))))
              '((label a f) (la t0 (a f))))

(check-equal? (flat '((module a (provide (d table)) (label d table))
                      (module b (require a) (la t0 (d table)))))
              '((label a d table) (la t0 (a d table))))

;; prefix-in 只给链的头加前缀
(check-equal? (flat '((module a (provide f) (provide (d table))
                                        (label f) (label d table))
                      (module b (require (prefix-in p: a))
                               (la t0 (p:f))
                               (la t1 (p:d table)))))
              '((label a f) (label a d table)
                (la t0 (a f)) (la t1 (a d table))))

;; rename-in: (外部链 -> 本地链)
(check-equal? (flat '((module a (provide f) (label f))
                      (module b (require (rename-in a ((f) tbl)))
                               (la t0 (tbl)))))
              '((label a f) (la t0 (a f))))

;; rename-out: 内部名 f, 外部名 fn
(check-equal? (flat '((module a (provide (rename-out ((f) fn))) (label f))
                      (module b (require a) (la t0 (fn)))))
              '((label a f) (la t0 (a f))))

;; (provide *) 只导出本模块直接定义的 label
(check-equal? (flat '((module a (provide *) (label d table) (label g))
                      (module b (require a) (la t0 (d table)))))
              '((label a d table) (label a g)
                (la t0 (a d table))))

;; re-export
(check-equal? (flat '((module a (provide f) (label f))
                      (module b (require a)
                                (provide (rename-out ((f) ff))))
                      (module c (require b) (la t0 (ff)))))
              '((label a f) (la t0 (a f))))

;; 根作用域也可以写 provide/require
(check-equal? (flat '((module a (provide f) (label f))
                      (require a)
                      (jal x0 (f))))
              '((label a f) (jal x0 (a f))))

;; 多个 require 子句叠加
(check-equal? (flat '((module a (provide f) (label f))
                      (module b (provide g) (label g))
                      (module c (require a) (require b)
                                (la t0 (f)) (la t1 (g)))))
              '((label a f) (label b g)
                (la t0 (a f)) (la t1 (b g))))

;; ---------------------------------------------------------------------------
;; 多输入共享名字表
;; ---------------------------------------------------------------------------

(define-values (outs names)
  (flatten-inputs
   (list '((module a (provide f) (label f)))
         '((module b (require a) (la t0 (f)))
           (label g)))))

(check-equal? outs
              '(((label a f))
                ((la t0 (a f)) (label g))))
(check-equal? (hash-ref names '(a f)) 0)
(check-equal? (hash-ref names '(g)) 1)

;; 跨输入直接引用根 label
(check-equal? (flatten-program '((label shared)))
              '((label shared)))
(define-values (outs2 _)
  (flatten-inputs (list '((label shared))
                        '((la t0 (shared))))))
(check-equal? outs2 '(((label shared)) ((la t0 (shared)))))

;; ---------------------------------------------------------------------------
;; 循环 require: 允许, 但必须有 base
;; ---------------------------------------------------------------------------

(check-equal? (flat '((module a (provide fa) (require b)
                               (label fa) (b64 (fb)))
                      (module b (provide fb) (require a)
                               (label fb) (b64 (fa)))))
              '((label a fa) (b64 (b fb))
                (label b fb) (b64 (a fa))))

(check-error "环里没有 base"
             (lambda ()
               (flat '((module a (provide fa) (require b))
                       (module b (provide fb) (require a))))))

;; ---------------------------------------------------------------------------
;; 默认私有 / 错误
;; ---------------------------------------------------------------------------

(check-error "没 provide, 写全名也引用不到"
             (lambda () (flat '((module a (label f))
                                (module b (la t0 (a f)))))))
(check-error "undefined label"
             (lambda () (flat '((label f) (jal x0 (nope))))))
(check-error "同一链两个位置"
             (lambda () (flat '((label f) (add t0 t1 t2) (label f)))))
(check-error "label 没有名字"
             (lambda () (flat '((label)))))
(check-error "label 链里混进非名字"
             (lambda () (flat '((label a (b))))))
(check-error "module 名字不合法"
             (lambda () (flat '((module (a) (label f))))))
(check-error "module 重名"
             (lambda () (flat '((module a (label f))
                                (module a (label g))))))
(check-error "provide 不存在"
             (lambda () (flat '((module a (provide nope) (label f))))))
(check-error "require 不存在的模块"
             (lambda () (flat '((module a (require ghost) (label f))))))
(check-error "required 名字与本地 label 冲突"
             (lambda () (flat '((module a (provide f) (label f))
                                (module b (require a) (label f))))))
(check-error "两个 require 给同一短名"
             (lambda () (flat '((module a (provide f) (label f))
                                (module b (provide f) (label f))
                                (module c (require a) (require b)
                                          (la t0 (f)))))))

;; ---------------------------------------------------------------------------
;; 容器 / 幂等 / flatten-items
;; ---------------------------------------------------------------------------

(check-equal? (flat '(begin (module a (label f)))) '((label a f)))
(check-equal? (flat '(quote ((module a (label f))))) '((label a f)))

(define once
  (flat '((module a (provide f) (label f)
           (module b (label g) (jal x0 (g)))))))
(check-equal? (flat once) once)

(define-values (items names2)
  (flatten-items '((module a (label f)))))
(check-equal? items '(((label a f))))
(check-equal? (hash-ref names2 '(a f)) 0)

(finish-tests "flatten")
