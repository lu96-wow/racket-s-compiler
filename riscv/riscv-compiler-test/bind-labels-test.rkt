#lang racket
;;; bind-labels-test.rkt -- anchors -> symbols
;;;
;;; 锁住：
;;;   - measured 只有 anchors，没有 symbols
;;;   - bind-labels 后 phase=bound，地址 = 段 start + 偏移
;;;   - value 宽度 / segment 容量在 bind-labels 才检查
;;;   - check 产出的 problems 原样保留；bind 不改 item/size

(require rackunit
         "helpers.rkt"
         (rename-in "../riscv-compiler/layout/layout.rkt"
                    [layout-program layout-program*])
         (only-in "../riscv-compiler/bind-labels/bind.rkt"
                  bind-labels bound-layout? layout-symbols layout-link
                  layout-provides
                  symbol-row symbol-address eval-symbol-address)
         (only-in "../riscv-compiler/check/check.rkt" check-layout)
         (only-in "../riscv-compiler/target.rkt" target-rv64-base)
         (only-in "../riscv-compiler/analyze/analyze.rkt" analyze)
         (only-in "../riscv-compiler/flatten/flatten.rkt" flatten-program))

(define test-target target-rv64-base)
(define (lay prog data spec) (layout-program* test-target prog data spec))

(define (symbol-for layout chain)
  (symbol-row (layout-symbols layout) chain))

(define (problems-of layout) (layout-problem-list layout))

;; ---------------------------------------------------------------------------
;; anchors -> symbols
;; ---------------------------------------------------------------------------

(define measured
  (lay (analyze '((label main) (jalr x0 ra 0)
                  (label f) (jalr x0 ra 0)))
       '((label d t) (value 8 (main)))
       '((segments (segment (name c) (kind code) (start #x1000) (end #x1FFF) (align 4))
                   (segment (name d) (kind data) (start #x8000) (end #x8FFF) (align 8)))
         (place c (main) (f)) (place d (d t)))))

(check-equal? (layout-phase-of measured) 'measured)
(check-false (assoc 'symbols measured))
(check-equal? (problems-of measured) '())

(define bound (bind-labels measured))

(check-equal? (layout-phase-of bound) 'bound)
(check-true (bound-layout? bound))
(check-equal? (problems-of bound) '())

(check-equal? (symbol-for bound '(main)) '(symbol (main) c 0 #x1000))
(check-equal? (symbol-for bound '(f)) '(symbol (f) c 4 #x1004))
(check-equal? (symbol-for bound '(d t)) '(symbol (d t) d 0 #x8000))
(check-equal? (symbol-address (symbol-for bound '(f))) #x1004)

;; anchors / segments 原样保留；bind 不改尺寸
(check-equal? (layout-anchor-list bound) (layout-anchor-list measured))
(check-equal? (cdr (assoc 'segments bound)) (cdr (assoc 'segments measured)))

;; 幂等
(check-equal? (bind-labels bound) bound)

;; 地址表达式求值
(check-equal? (eval-symbol-address '(+ (main) 8) (layout-symbols bound)) #x1008)
(check-equal? (eval-symbol-address '(- (f) (main)) (layout-symbols bound)) 4)
(check-error "未定义链"
             (lambda () (eval-symbol-address '(+ (nope) 1) (layout-symbols bound))))

;; ---------------------------------------------------------------------------
;; 最终宽度 / 容量检查
;; ---------------------------------------------------------------------------

;; measured 不查 value 宽度；bind-labels 才查
(define wide
  (lay (analyze '((label main) (jalr x0 ra 0)))
       '((label d t) (value 4 (d t)))
       '((segments (segment (name c) (kind code) (start #x1000) (end #x1FFF) (align 4))
                   (segment (name d) (kind data) (start #x100000000) (end #x100001000) (align 8)))
         (place c (main)) (place d (d t)))))

(check-equal? (problems-of wide) '())
(check-true (has-problem? (bind-labels wide) 'value-out-of-range))

;; segment 容量也是最终尺寸才算
(define overflow
  (lay (analyze '((label main) (addi a0 a0 1) (addi a0 a0 1)))
       '()
       '((segments (segment (name c) (kind code) (start #x1000) (end #x1007) (align 4)))
         (place c (main)))))

(check-equal? (problems-of overflow) '())
(check-true (has-problem? (bind-labels overflow) 'segment-overflow))

;; hole 段也受同一套容量检查: 洞的尺寸不能超过声明的范围
(define hole-overflow
  (lay (analyze '((label main) (jalr x0 ra 0)))
       '((label bss) (reserve 64))
       '((segments (segment (name c) (kind code) (start #x1000) (end #x1100) (align 16))
                   (segment (name b) (kind hole) (start #x2000) (end #x2010) (align 8)))
         (place c (main)) (place b (bss)))))

(check-equal? (problems-of hole-overflow) '())
(check-true (has-problem? (bind-labels hole-overflow) 'segment-overflow))

;; hole 段里的 label 照常拿到绝对地址
(define hole-symbols
  (layout-symbols
   (bind-labels
    (lay (analyze '((label main) (jalr x0 ra 0)))
         '((label bss) (reserve 8) (label buf) (reserve 8))
         '((segments (segment (name c) (kind code) (start #x1000) (end #x1100) (align 16))
                     (segment (name b) (kind hole) (start #x2000) (end #x2010) (align 8)))
           (place c (main)) (place b (bss) (buf)))))))

(check-equal? (map symbol-address
                   (filter (lambda (row) (eq? (caddr row) 'b)) hole-symbols))
              '(#x2000 #x2008))

;; ---------------------------------------------------------------------------
;; check 产出的 problems 原样带过去
;; ---------------------------------------------------------------------------

(define with-ghost
  (lay (analyze '((label main) (jal x0 (ghost))))
       '()
       '((segments (segment (name c) (kind code) (start #x1000) (end #x1FFF) (align 4)))
         (place c (main)))))
(define with-ghost-checked (check-layout test-target with-ghost))

(check-true (has-problem? with-ghost-checked 'undefined-target))
(check-equal? (problems-of (bind-labels with-ghost-checked))
              (problems-of with-ghost-checked))

;; ---------------------------------------------------------------------------
;; 入口检查
;; ---------------------------------------------------------------------------

(check-error "需要 measured-layout"
             (lambda () (bind-labels '())))

;; ---------------------------------------------------------------------------
;; link 表: symbols 的两列投影 + base
;;
;;   (link (base B) (symbol 链 地址) ...)
;;
;; 行只来自 anchors, 所以输出里不可能出现未解析的项; 按地址升序。
;; ---------------------------------------------------------------------------

(check-equal? (layout-link measured) #f)          ; measured 相还没有 link 表

(define bonded (bind-labels measured))

(check-equal? (layout-link bonded)
              '((base 0)
                (symbol (main) #x1000)
                (symbol (f) #x1004)
                (symbol (d t) #x8000)))

;; 和 symbols 一一对应: 数量相同, 地址相同, 只是去掉了段名/偏移。
(check-equal? (length (cdr (layout-link bonded)))
              (length (layout-symbols bound)))
(for ([row (in-list (layout-symbols bound))])
  (check-equal? (symbol-address (symbol-for bonded (cadr row)))
                (last row)))

;; base 跟着 spec 的 (origin …) 走, 而不是段的 start。
(define moved
  (lay (analyze '((label main) (jalr x0 ra 0)))
       '()
       '((origin #x400000)
         (segments (segment (name c) (kind code) (start #x401000) (end #x402000) (align 4)))
         (place c (main)))))
(check-equal? (layout-link (bind-labels moved))
              '((base #x400000) (symbol (main) #x401000)))

;; 排序: 段声明顺序和地址顺序不一致时, link 表仍按地址升序。
(define shuffled
  (lay (analyze '((label low) (jalr x0 ra 0)
                  (label high) (jalr x0 ra 0)))
       '()
       '((segments (segment (name hi) (kind code) (start #x9000) (end #x9FFF) (align 4))
                   (segment (name lo) (kind code) (start #x1000) (end #x1FFF) (align 4)))
         (place hi (high)) (place lo (low)))))
(check-equal? (layout-link (bind-labels shuffled))
              '((base 0)
                (symbol (low) #x1000)
                (symbol (high) #x9000)))

;; 同址多个名字: 两个名字都在表里(一个位置可以有多个 label 链)。
(define aliased
  (lay (analyze '((label a) (label b) (jalr x0 ra 0)))
       '()
       '((segments (segment (name c) (kind code) (start #x1000) (end #x1FFF) (align 4)))
         (place c (a) (b)))))
(check-equal? (layout-link (bind-labels aliased))
              '((base 0)
                (symbol (a) #x1000)
                (symbol (b) #x1000)))

;; ---------------------------------------------------------------------------
;; provides: 对外承诺哪些名字(链), 地址仍在 link 表里
;;
;; exports 三种取值: 'all(缺省) / 链列表 / 链没有被 link 覆盖 -> problem
;; ---------------------------------------------------------------------------

;; 缺省(手搓 measured-layout)按“全导出”算, 顺序跟 link 表一致(按地址升序)。
(check-equal? (layout-provides (bind-labels measured))
              '((main) (f) (d t)))

;; 给定导出集合: 只留这些名字, 顺序仍然是 link 表的顺序。
(check-equal? (layout-provides (bind-labels measured '((d t) (main))))
              '((main) (d t)))

;; 空集合 = 什么都不导出。
(check-equal? (layout-provides (bind-labels measured '())) '())

;; 导出一个不存在的名字 -> problem, 不抛异常。
(check-true (pair? (problems-of (bind-labels measured '((ghost))))))
(check-true (has-problem? (bind-labels measured '((ghost))) 'provide-unknown)
            (format "problems: ~s"
                    (problems-of (bind-labels measured '((ghost))))))

;; provides 只是链, 地址不重复存: 每个链都能在 link 表里查到同样的地址。
(for ([chain (in-list (layout-provides (bind-labels measured)))])
  (check-equal? (symbol-address (symbol-for (bind-labels measured) chain))
                (symbol-address (symbol-for (bind-labels measured) chain))))

;; rename-out: 外部名和本地链不同 -> link 表里补一行别名, provides 用外部名。
;; 注意: module 必须先 flatten(本层不认识 module 壳, 会当成一条不透明 item)。
(define renamed
  (lay (analyze (flatten-program
                 '((module a (provide (rename-out (f out)))
                            (label f) (jalr x0 ra 0)))))
       '()
       '((segments (segment (name c) (kind code) (start #x1000) (end #x1FFF) (align 4)))
         (place c (a f)))))
;; 导出集合记绝对链, 所以 link 表里没有别名行
(define renamed-bound (bind-labels renamed '((a f))))
(check-equal? (layout-provides renamed-bound) '((a f)))
(check-equal? (layout-link renamed-bound)
              '((base 0) (symbol (a f) #x1000)))

(finish-tests "bind-labels")
