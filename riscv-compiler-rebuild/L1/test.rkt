#lang racket
;;; L1/test.rkt

(require rackunit
         "flatten.rkt")

(define (flat x) (flatten-program x))

;; ---------------------------------------------------------------------------
;; 展平: module 只是作用域前缀
;; ---------------------------------------------------------------------------

(check-equal? (flat '((module a (label f))))
              '(quote ((label a f))))

;; 用户给的规则
(check-equal? (flat '((module a (label b c))))
              '(quote ((label a b c))))

;; 嵌套模块: 一层前缀一层
(check-equal? (flat '((module a (module b (label f)))))
              '(quote ((label a b f))))
(check-equal? (flat '((module a (module b (module c (label f))))))
              '(quote ((label a b c f))))

;; 模块比 label 深: 先把结构展平, 前缀顺序 = 外->内
(check-equal? (flat '((module a (add t0 t1 t2) (module b (label f)))))
              '(quote ((add t0 t1 t2) (label a b f))))

;; 名字不限类型
(check-equal? (flat '((module 1 (label "x")))) '(quote ((label 1 "x"))))
(check-equal? (flat '((label "x" 2)))          '(quote ((label "x" 2))))
(check-equal? (flat '((module "m" (label 3))))  '(quote ((label "m" 3))))

;; (label a a) 是一条链(作用域 a 里的 a), 不是重名
(check-equal? (flat '((label a a))) '(quote ((label a a))))
(check-equal? (flat '((label a a) (label a b)))
              '(quote ((label a a) (label a b))))

;; ---------------------------------------------------------------------------
;; 一个位置多个名字 = 连续多条 label
;; ---------------------------------------------------------------------------

(check-equal? (flat '((label f) (label g)))
              '(quote ((label f) (label g))))
(check-equal? (flat '((module a (label f) (label g))))
              '(quote ((label a f) (label a g))))

;; 同位置写两遍同名: 忽略重复
(check-equal? (flat '((label f) (label f))) '(quote ((label f))))

(define-values (multi-items multi-table)
  (flatten-items '((module a (label f) (label g) (add t0 t1 t2)))))
(check-equal? (hash-ref multi-table '(a f)) (hash-ref multi-table '(a g)))

(define-values (_ two-slots)
  (flatten-items '((label f) (add t0 t1 t2) (label g))))
(check-false (= (hash-ref two-slots '(f)) (hash-ref two-slots '(g))))

;; ---------------------------------------------------------------------------
;; 链式查表
;; ---------------------------------------------------------------------------

;; 先试内层 (a g)
(check-equal? (flat '((module a (label f) (jal x0 (g)) (label g))))
              '(quote ((label a f) (jal x0 (a g)) (label a g))))

;; 内层没有就退到外层/全局
(check-equal? (flat '((label h) (module a (label f) (jal x0 (h)))))
              '(quote ((label h) (label a f) (jal x0 (h)))))

;; 两层都有: 内层遮蔽外层
(check-equal? (flat '((label h)
                      (add t0 t1 t2)
                      (module a (label h) (jal x0 (h)))))
              '(quote ((label h) (add t0 t1 t2) (label a h) (jal x0 (a h)))))

;; 引用别的模块: 写完整链
(check-equal? (flat '((module a (label f))
                      (module b (label g) (jal ra (a f)))))
              '(quote ((label a f) (label b g) (jal ra (a f)))))

;; 跨层的相对链: 在 (a b) 里写 (b f) 也会按 a.b.f 试
(check-equal? (flat '((module a (module b (label f) (jal x0 (f))))))
              '(quote ((label a b f) (jal x0 (a b f)))))

;; ---------------------------------------------------------------------------
;; 只改链, 裸原子(寄存器/立即数/裸 label 名)不动
;; ---------------------------------------------------------------------------

(check-equal? (flat '((label f) (add t0 t1 42) (lw t0 t1 8) (jal x0 t0)))
              '(quote ((label f) (add t0 t1 42) (lw t0 t1 8) (jal x0 t0))))

;; 指令参数里的链也照答
(check-equal? (flat '((label f) (la t0 (f))))
              '(quote ((label f) (la t0 (f)))))

;; ---------------------------------------------------------------------------
;; 容器 / 幂等
;; ---------------------------------------------------------------------------

(check-equal? (flat '(begin (module a (label f)) (jal x0 (a f))))
              '(quote (begin (label a f) (jal x0 (a f)))))

;; 已经展平的程序再展平一次: 不变
(define once (flat '((module a (label f) (jal x0 (g)) (label g)))))
(check-equal? (flat once) once)

;; ---------------------------------------------------------------------------
;; 错误
;; ---------------------------------------------------------------------------

;; 引用不存在
(check-exn exn:fail? (lambda () (flat '((label f) (jal x0 (nope))))))
;; 同一条链出现在两个不同位置
(check-exn exn:fail? (lambda () (flat '((label f) (add t0 t1 t2) (label f)))))
;; label 没有名字
(check-exn exn:fail? (lambda () (flat '((label)))))
;; label 的链里混进了非名字
(check-exn exn:fail? (lambda () (flat '((label a (b))))))
(check-exn exn:fail? (lambda () (flat '((label #t)))))
;; module 没有合法名字
(check-exn exn:fail? (lambda () (flat '((module (a) (label f))))))
(check-exn exn:fail? (lambda () (flat '((module (label f))))))

(displayln "L1 tests: ok")
