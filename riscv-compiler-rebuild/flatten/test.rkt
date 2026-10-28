#lang racket
;;; flatten/test.rkt

(require rackunit
         "flatten.rkt")

(define (flat x) (flatten-program x))

;; ---------------------------------------------------------------------------
;; 空输入 / 旧壳
;; ---------------------------------------------------------------------------

(check-equal? (flat '()) '())
(check-equal? (flat '(quote ())) '())
(check-equal? (flat '(begin)) '())

;; ---------------------------------------------------------------------------
;; 展平: module 只是作用域前缀
;; ---------------------------------------------------------------------------

(check-equal? (flat '((module a (label f))))
              '((label a f)))

;; 用户给的规则
(check-equal? (flat '((module a (label b c))))
              '((label a b c)))

;; 嵌套模块: 一层前缀一层
(check-equal? (flat '((module a (module b (label f)))))
              '((label a b f)))
(check-equal? (flat '((module a (module b (module c (label f))))))
              '((label a b c f)))

;; 模块比 label 深: 先把结构展平, 前缀顺序 = 外->内
(check-equal? (flat '((module a (add t0 t1 t2) (module b (label f)))))
              '((add t0 t1 t2) (label a b f)))

;; 名字不限类型
(check-equal? (flat '((module 1 (label "x")))) '((label 1 "x")))
(check-equal? (flat '((label "x" 2)))          '((label "x" 2)))
(check-equal? (flat '((module "m" (label 3))))  '((label "m" 3)))

;; (label a a) 是一条链(作用域 a 里的 a), 不是重名
(check-equal? (flat '((label a a))) '((label a a)))
(check-equal? (flat '((label a a) (label a b)))
              '((label a a) (label a b)))

;; ---------------------------------------------------------------------------
;; 一个位置多个名字 = 连续多条 label
;; ---------------------------------------------------------------------------

(check-equal? (flat '((label f) (label g)))
              '((label f) (label g)))
(check-equal? (flat '((module a (label f) (label g))))
              '((label a f) (label a g)))

;; 同位置写两遍同名: 忽略重复
(check-equal? (flat '((label f) (label f))) '((label f)))

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
              '((label a f) (jal x0 (a g)) (label a g)))

;; 内层没有就退到外层/全局
(check-equal? (flat '((label h) (module a (label f) (jal x0 (h)))))
              '((label h) (label a f) (jal x0 (h))))

;; 两层都有: 内层遮蔽外层
(check-equal? (flat '((label h)
                      (add t0 t1 t2)
                      (module a (label h) (jal x0 (h)))))
              '((label h) (add t0 t1 t2) (label a h) (jal x0 (a h))))

;; 引用别的模块: 必须 provide + require（默认私有）
(check-equal? (flat '((module a (provide f) (label f))
                      (module b (require a) (label g) (jal ra (f)))))
              '((label a f) (label b g) (jal ra (a f))))
;; 没有 provide 的内部 label, 写完整链也引用不到
(check-exn exn:fail?
           (lambda () (flat '((module a (label f))
                               (module b (label g) (jal ra (a f)))))))

;; 跨层的相对链: 在 (a b) 里写 (b f) 也会按 a.b.f 试
(check-equal? (flat '((module a (module b (label f) (jal x0 (f))))))
              '((label a b f) (jal x0 (a b f))))

;; ---------------------------------------------------------------------------
;; 只改链, 裸原子(寄存器/立即数/裸 label 名)不动
;; ---------------------------------------------------------------------------

(check-equal? (flat '((label f) (add t0 t1 42) (lw t0 t1 8) (jal x0 t0)))
              '((label f) (add t0 t1 42) (lw t0 t1 8) (jal x0 t0)))

;; 指令参数里的链也照答
(check-equal? (flat '((label f) (la t0 (f))))
              '((label f) (la t0 (f))))

;; ---------------------------------------------------------------------------
;; 容器 / 幂等
;; ---------------------------------------------------------------------------

(check-equal? (flat '((module a (provide f) (label f)) (require a) (jal x0 (f))))
              '((label a f) (jal x0 (a f))))

;; 旧壳 (quote ...)/(begin ...) 也收, 出口一律 plain list
(check-equal? (flat '(begin (module a (label f)))) '((label a f)))
(check-equal? (flat '(quote ((module a (label f))))) '((label a f)))

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

;; ---------------------------------------------------------------------------
;; 多输入: 程序 + 数据共享一张名字表
;; ---------------------------------------------------------------------------

(define-values (ins _names)
  (flatten-inputs (list '((module prog1
                                   (require data1)
                                   (label main)
                                   (la t0 (table)))
                          (label root))
                         '((module data1
                                   (provide table)
                                   (label table)
                                   (bytes 1 2 3))))))

;; 两个输入各自展平, 跨输入的模块照样能 require
(check-equal? (list-ref ins 0)
              '((label prog1 main) (la t0 (data1 table)) (label root)))
(check-equal? (list-ref ins 1)
              '((label data1 table) (bytes 1 2 3)))

;; 没有 provide 的模块, 写完整链也引用不到
(check-exn exn:fail?
           (lambda ()
             (flatten-inputs (list '((module prog1 (label main) (la t0 (data1 table))))
                                   '((module data1 (label table)))))))

;; ---------------------------------------------------------------------------
;; 压缩指令: flatten 不认助记符, 只改操作数里的链
;; ---------------------------------------------------------------------------

;; c.* 原样保留, 目标是链的照样解析
(check-equal? (flat '((label a) (c.j (b)) (label b) (c.addi a0 1)))
              '((label a) (c.j (b)) (label b) (c.addi a0 1)))
(check-equal? (flat '((module m (label a) (c.beqz t0 (b)) (label b))))
              '((label m a) (c.beqz t0 (m b)) (label m b)))
;; 寄存器/立即数是裸原子, 不动
(check-equal? (flat '((c.addi4spn a0 sp 8) (c.li a1 -1) (c.nop)))
              '((c.addi4spn a0 sp 8) (c.li a1 -1) (c.nop)))
;; 链不在操作数里(是链)才算引用: (c.j b) 的 b 是裸原子, 不当引用
(check-equal? (flat '((label b) (c.j b))) '((label b) (c.j b)))

;; ---------------------------------------------------------------------------
;; 地址表达式: 链藏在操作数里面, 也要改写
;;   … / (+ …) / (- …) —— 数据里的地址字
;; ---------------------------------------------------------------------------

(check-equal? (flat '((module m (label d t) (value 8 (d t)))))
              '((label m d t) (value 8 (m d t))))

;; 同一条程序里: 指令操作数、地址字、负加数都要加前缀
(check-equal? (flat '((module m
                       (label d t)
                       (value 8 (d t))
                       (label f)
                       (la t0 (f))
                       (value 4 (- (f) 4)))))
              '((label m d t)
                (value 8 (m d t))
                (label m f)
                (la t0 (m f))
                (value 4 (- (m f) 4))))

;; 两条链的地址表达式两条都要加前缀
(check-equal? (flat '((module m (label d start) (label d end)
                       (value 4 (- (d end) (d start))))))
              '((label m d start) (label m d end)
                (value 4 (- (m d end) (m d start)))))
(check-equal? (flat '((module m (label d start) (label d end)
                       (value 4 (- (d end) (d start) 4)))))
              '((label m d start) (label m d end)
                (value 4 (- (m d end) (m d start) 4))))

;; 两层作用域: 内层优先
(check-equal? (flat '((module a (label g) (module b (label g) (value 4 (g))))))
              '((label a g) (label a b g) (value 4 (a b g))))

;; 地址表达式里的链查不到 -> 报错(不是静默留短链)
(check-exn exn:fail?
           (lambda () (flat '((module m (label f) (value 4 (nope)))))))

;; ---------------------------------------------------------------------------
;; 模块系统: provide / require / prefix-in / rename-in / rename-out
;; ---------------------------------------------------------------------------

;; 默认私有: 外部写完整链也找不到
(check-exn exn:fail?
           (lambda () (flat '((module a (label f)) (module b (la t0 (a f)))))))

;; provide + require: 用短名, 输出仍是完整链
(check-equal? (flat '((module a (provide f) (label f))
                      (module b (require a) (la t0 (f)))))
              '((label a f) (la t0 (a f))))

;; 多层链的 label 也能导出/导入
(check-equal? (flat '((module a (provide (d table)) (label d table))
                      (module b (require a) (la t0 (d table)))))
              '((label a d table) (la t0 (a d table))))

;; prefix-in: 绑成 p:名字
(check-equal? (flat '((module a (provide f) (label f))
                      (module b (require (prefix-in dt: a)) (la t0 (dt:f)))))
              '((label a f) (la t0 (a f))))

;; rename-in: 导入时改名
(check-equal? (flat '((module a (provide f) (label f))
                      (module b (require (rename-in a ((f) tbl))) (la t0 (tbl)))))
              '((label a f) (la t0 (a f))))

;; rename-out: 导出时改名（内部名仍叫 f, 外部叫 fn）
(check-equal? (flat '((module a (provide (rename-out ((f) fn))) (label f))
                      (module b (require a) (la t0 (fn)))))
              '((label a f) (la t0 (a f))))

;; (provide *) 导出本模块直接定义的 label, 用它们的本地链
(check-equal? (flat '((module a (provide *) (label d table) (label g))
                      (module b (require a) (la t0 (d table)))))
              '((label a d table) (label a g) (la t0 (a d table))))

;; re-export: b 把 require 进来的再 provide 出去
(check-equal? (flat '((module a (provide f) (label f))
                      (module b (require a) (provide (rename-out ((f) ff))))
                      (module c (require b) (la t0 (ff)))))
              '((label a f) (la t0 (a f))))

;; 多个 require 子句可以叠加
(check-equal? (flat '((module a (provide f) (label f))
                      (module b (provide g) (label g))
                      (module c (require a) (require b)
                                (la t0 (f)) (la t1 (g)))))
              '((label a f) (label b g) (la t0 (a f)) (la t1 (b g))))

;; 冲突: require 进来的名字和本模块 label 同名 -> 报错
(check-exn exn:fail?
           (lambda () (flat '((module a (provide f) (label f))
                               (module b (require a) (label f))))))
;; 冲突: 两个 require 给同一个短名, 指向不同目标 -> 报错
(check-exn exn:fail?
           (lambda () (flat '((module a (provide f) (label f))
                               (module b (provide f) (label f))
                               (module c (require a) (require b) (la t0 (f)))))))
;; 循环 require 是**允许**的（地址引用不涉及初始化顺序）: 数据 <-> 代码 就是这样
(check-equal? (flat '((module a (provide fa) (require b)
                                 (label fa) (b64 (fb)))
                      (module b (provide fb) (require a)
                                 (label fb) (b64 (fa)))))
              '((label a fa) (b64 (b fb))       ; rich 数据本层不展开
                (label b fb) (b64 (a fa))))
;; 环里没有 base(全靠 re-export) -> 解不出来, 报错
(check-exn exn:fail?
           (lambda () (flat '((module a (provide fa) (require b))
                               (module b (provide fb) (require a))))))
;; provide 了不存在的东西 -> 报错（不用等别人 require）
(check-exn exn:fail? (lambda () (flat '((module a (provide nope) (label f))))))
;; require 不存在的模块 -> 报错
(check-exn exn:fail? (lambda () (flat '((module a (require ghost) (label f))))))
;; 模块不能重名
(check-exn exn:fail? (lambda () (flat '((module a (label f)) (module a (label g))))))
;; 同一模块里 label 与 require 绑定同名, 但引用的还是本模块的
(check-equal? (flat '((module a (provide f) (label f))
                      (module b (require a) (label f2) (la t0 (f)))))
              '((label a f) (label b f2) (la t0 (a f))))

(displayln "flatten tests: ok")
