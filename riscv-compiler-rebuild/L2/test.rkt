#lang racket
;;; L2/test.rkt

(require rackunit
         "table-base.rkt"
         "table.rkt"
         "rewrite.rkt")

(define (rw x) (rewrite-all x))

;; --- 显式 / 简写等价 -------------------------------------------------------
(check-equal? (rw '(load-32 t0 sp 8)) '(lwu t0 sp 8))
(check-equal? (rw '(l32     t0 sp 8)) '(lwu t0 sp 8))

(check-equal? (rw '(load-8 t0 a)) '(lbu t0 a 0))
(check-equal? (rw '(l8     t0 a)) '(lbu t0 a 0))

(check-equal? (rw '(load-16  t0 a 4)) '(lhu t0 a 4))
(check-equal? (rw '(load-64  t0 a 8)) '(ld  t0 a 8))
(check-equal? (rw '(load-s8  t0 a))   '(lb  t0 a 0))
(check-equal? (rw '(load-s16 t0 a 2)) '(lh  t0 a 2))
(check-equal? (rw '(load-s32 t0 a))   '(lw  t0 a 0))
(check-equal? (rw '(ls32     t0 a))   '(lw  t0 a 0))

;; --- 存储: 操作数顺序被摆正 ------------------------------------------------
(check-equal? (rw '(store-8  a s))     '(sb s a 0))
(check-equal? (rw '(store-8  a 8 s))   '(sb s a 8))
(check-equal? (rw '(store-16 a s))     '(sh s a 0))
(check-equal? (rw '(store-32 a 4 t0))  '(sw t0 a 4))
(check-equal? (rw '(store-64 a ra))    '(sd ra a 0))
(check-equal? (rw '(st64     sp 16 ra))'(sd ra sp 16))

;; --- move ------------------------------------------------------------------
(check-equal? (rw '(move t0 t1)) '(add t0 t1 x0))
(check-equal? (rw '(mv   t0 t1)) '(add t0 t1 x0))

;; --- 分支换位 --------------------------------------------------------------
(check-equal? (rw '(branch-le  a b L)) '(bge  b a L))
(check-equal? (rw '(branch-gt  a b L)) '(blt  b a L))
(check-equal? (rw '(branch-leu a b L)) '(bgeu b a L))
(check-equal? (rw '(branch-gtu a b L)) '(bltu b a L))
(check-equal? (rw '(ble        a b L)) '(bge  b a L))
(check-equal? (rw '(bgtu       a b L)) '(bltu b a L))

;; --- 透传 ------------------------------------------------------------------
(check-equal? (rw '(add t0 t1 t2)) '(add t0 t1 t2))
(check-equal? (rw '(lb  t0 t1 0))  '(lb  t0 t1 0))
(check-equal? (rw '(li  t0 42))    '(li  t0 42))
(check-equal? (rw '(ecall))        '(ecall))
(check-equal? (rw 'hello)          'hello)
(check-equal? (rw 42)              42)

;; 形状不匹配 -> 原样保留(含原拼写), 交给编码器报错
(check-equal? (rw '(load-32 t0))           '(load-32 t0))
(check-equal? (rw '(l8 t0 a 0 extra))      '(l8 t0 a 0 extra))

;; --- item 列表 --------------------------------------------------------------
(check-equal? (rw '(label L))
              '(label L))
(check-equal? (rw '((load-32 t0 sp 8) (store-64 sp 16 ra)))
              '((lwu t0 sp 8) (sd ra sp 16)))

;; 操作数是值: 嵌套写在操作数里的伪指令不展开(展平后不存在这种写法)
(check-equal? (rw '(move t0 (load-32 t1 sp 8)))
              '(add t0 (load-32 t1 sp 8) x0))

;; 链 (a g) 也是值: 不会被当成指令 (a g) 改写
(check-equal? (rw '(jal x0 (l8 foo))) '(jal x0 (l8 foo)))
(check-equal? (rw '(la t0 (move mv))) '(la t0 (move mv)))
(check-false (pseudo-leftover? '(jal x0 (l8 foo))))

;; --- quote 不进 ------------------------------------------------------------
(check-equal? (rw '(quote (load-32 t0 sp 8)))
              '(quote (load-32 t0 sp 8)))

;; --- 验证器 ----------------------------------------------------------------
(check-false (pseudo-leftover? (rw '((load-32 t0 sp 8) (store-64 sp 16 ra)))))
(check-true  (pseudo-leftover? '(load-32 t0 sp 8)))
(check-false (pseudo-leftover? '(lwu t0 sp 8)))
(check-true  (fully-rewritten? '(lwu t0 sp 8)))
(check-false (fully-rewritten? '(load-32 t0 sp 8)))
;; quote 里的数据不算残留
(check-true  (fully-rewritten? '(quote (load-32 t0 sp 8))))

;; 幂等
(check-equal? (rw (rw '((l8 t0 a) (ble a b L))))
              (rw '((l8 t0 a) (ble a b L))))

;; --- 层入口: 进 list, 出也一定是 list ---------------------------------------
(check-equal? (rewrite-program '((load-32 t0 sp 8) (store-64 sp 16 ra) L))
              '((lwu t0 sp 8) (sd ra sp 16) L))
(check-equal? (rewrite-program '(l8 t0 a)) '((lbu t0 a 0)))

;; 旧壳 (quote ...) / (begin ...) 也收, 出口一律 plain list
(check-equal? (rewrite-program '(quote ((l8 t0 a)))) '((lbu t0 a 0)))
(check-equal? (rewrite-program '(begin (l8 t0 a)))   '((lbu t0 a 0)))

;; 出口里不再有 P-asm 拼写
(define out (rewrite-program '((ls8 t1 t0) (ble t1 t0 L) (mv t0 t1))))
(check-false (pseudo-leftover? out))

;; 幂等: 结果再跑一次不变
(check-equal? (rewrite-program out) out)

;; 代码内部的 quote 仍是数据, 不进去
(check-equal? (rewrite-program '((quote (load-32 t0 sp 8))))
              '((quote (load-32 t0 sp 8))))

;; --- 多命名: 同级 ------------------------------------------------------------
(check-true  (pseudo-name? 'l8))
(check-true  (pseudo-name? 'load-8))
(check-false (pseudo-name? 'lb))

;; 同一行的名字平级: 谁做头都是同一组规则
(check-equal? (rw '(l8 t0 a))          (rw '(load-8 t0 a)))
(check-equal? (rw '(ls16 t0 a 2))      (rw '(load-s16 t0 a 2)))
(check-equal? (rw '(st64 sp 16 ra))    (rw '(store-64 sp 16 ra)))
(check-equal? (rw '(mv t0 t1))         (rw '(move t0 t1)))
(check-equal? (rw '(bleu a b L))       (rw '(branch-leu a b L)))

;; 每个名字都能触发重写, 且规则取自同一行
(for ([row (in-list rewrite-rows)])
  (define names (row-names row))
  (define rs (row-rules row))
  (check-true (>= (length names) 2) (format "~a: rows should have >=2 names" names))
  (for ([s (in-list names)])
    (check-true (pseudo-name? s))
    (check-equal? (rules-for s) rs)))

;; 规则视图: 操作数模式是 list, 模板是个 form
(for ([r (in-list rules)])
  (check-true (list? (car r)))
  (check-true (form? (cadr r))))

;; --- 建表自检 ---------------------------------------------------------------
;; 同一行里名字重复
(check-exn exn:fail?
           (lambda () (validate-rows! '((load-8 load-8 ((?d ?a) (lbu ?d ?a 0)))))))
;; 名字被两行占
(check-exn exn:fail?
           (lambda () (validate-rows! '((a x ((?d) (a ?d)))
                                      (b x ((?d) (b ?d)))))))
;; 占用指令头保留字
(check-exn exn:fail?
           (lambda () (validate-rows! '((load-8 quote ((?d ?a) (lb ?d ?a 0)))))))
;; 操作数模式不是列表
(check-exn exn:fail?
           (lambda () (validate-rows! '((load-8 l8 (?d (lbu ?d x x)))))))
;; 模板不是 form
(check-exn exn:fail?
           (lambda () (validate-rows! '((load-8 l8 ((?d ?a) foo))))))
;; 但模板写什么后端指令本层不管(扩展太多, 由后端报错)
(validate-rows! '((load-8 l8 ((?d ?a) (foo ?d ?a)))))
;; 名字也可以和真指令同名, 只要不是指令头
(validate-rows! '((load-8 lbu ((?d ?a) (lbu ?d ?a 0)))))
;; 行只有名字没规则
(check-exn exn:fail?
           (lambda () (validate-rows! '((load-8 l8)))))

;; --- 表按扩展拆文件, 由 table.rkt 聚合 -------------------------------------
(check-true (list? rewrite-rows))
(check-eq? rewrite-rows (table-rows default-table))   ; rewrite.rkt 用的就是聚合出来的那张
(check-eq? rules (table-rules default-table))

;; base 扩展的每一行都原样进了聚合表(顺序 = 各扩展内部顺序)
(for ([row (in-list base-rewrite-rows)])
  (check-true (and (member row rewrite-rows) #t)))

;; 聚合只是 append: 两份行拼起来照样建表, 名字按文件顺序
(define t-two-files
  (make-table (append '((v1 v2 ((?d) (lb ?d x0 0))))     ; 假装是 table-vector.rkt
                      '((w1 w2 ((?d) (lh ?d x0 0)))))))  ; 假装是另一个扩展
(check-equal? (table-names t-two-files) '(v1 v2 w1 w2))
(check-equal? (rewrite-one '(v2 t0) t-two-files) '(lb t0 x0 0))
(check-equal? (rewrite-one '(w1 t0) t-two-files) '(lh t0 x0 0))

;; 跨文件重名会被聚合后的自检抓住
(check-exn exn:fail?
           (lambda () (validate-rows! (append '((v1 ((?d) (lb ?d x0 0))))
                                              '((v1 ((?d) (lh ?d x0 0))))))))

;; --- 别名的个数不定 ---------------------------------------------------------
;; 一行前面有几个 symbol 就有几个名字, 1 个、3 个、4 个都按同一种方式处理。
(define t-var
  (make-table '((one ((?d ?a) (lb ?d ?a 0)))                       ; 1 个名字
                (two t2 tw ((?d ?a) (lh ?d ?a 0)))                 ; 3 个名字
                (four f4 fo4 fou4 foe4 ((?d ?a) (ld ?d ?a 0))))))  ; 4 个名字

(check-equal? (table-names t-var)
              '(one two t2 tw four f4 fo4 fou4 foe4))
(check-equal? (length (table-rules t-var)) 3)

;; 每个名字都能查表、都能按同一行规则重写
(for ([n (in-list (table-names t-var))])
  (check-true (pseudo-name? n t-var)))
(for ([n (in-list '(two t2 tw))])
  (check-equal? (rewrite-one (list n 't0 'a) t-var) '(lh t0 a 0)))
(for ([n (in-list '(four f4 fo4 fou4 foe4))])
  (check-equal? (rewrite-all (list n 't0 'a) t-var) '(ld t0 a 0)))

;; 自定义表不影响默认表
(check-false (pseudo-name? 'tw))
(check-false (rewrite-one '(tw t0 a)))
(check-equal? (rules-for 'one) '())

;; 自定义表也能走整层入口, 出口仍是 quote-list
(check-equal? (rewrite-program '((tw t0 a) (fo4 t1 a)) t-var)
              '((lh t0 a 0) (ld t1 a 0)))

;; 5 个名字也行(个数没有上限)
(define t-many
  (make-table '((a1 a2 a3 a4 a5 ((?d ?a) (lb ?d ?a 0))))))
(check-equal? (table-names t-many) '(a1 a2 a3 a4 a5))
(for ([n (in-list '(a1 a2 a3 a4 a5))])
  (check-equal? (rewrite-one (list n 't0 'a) t-many) '(lb t0 a 0)))

;; --- 展开链自环保护 ---------------------------------------------------------
;; 表里写出一行自己展开成自己, 不能卡死
(define t-loop (make-table '((loop ((?d) (loop ?d))))))
(check-exn exn:fail? (lambda () (rewrite-all '(loop t0) t-loop)))

;; 两行互相展开也算自环
(define t-pingpong (make-table '((ping ((?d) (pong ?d)))
                                 (pong ((?d) (ping ?d))))))
(check-exn exn:fail? (lambda () (rewrite-all '(ping t0) t-pingpong)))

;; 正常的多步展开(链长 < 上限)不受影响
(define t-chain (make-table '((step1 ((?d) (step2 ?d)))
                              (step2 ((?d) (step3 ?d)))
                              (step3 ((?d) (add ?d x0 x0))))))
(check-equal? (rewrite-all '(step1 t0) t-chain) '(add t0 x0 x0))

;; rules-for 对不认识的输入统一返回 '()
(check-equal? (rules-for 'nope) '())
(check-equal? (rules-for 42) '())
(check-equal? (rules-for '(a b)) '())

(displayln "L2 tests: ok")
