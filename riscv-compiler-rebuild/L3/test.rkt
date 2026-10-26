#lang racket
;;; L3/test.rkt -- 控制流分析(只分析, 不改程序)

(require rackunit
         "insn.rkt"
         "analyze.rkt"
         (prefix-in cfg: "cfg.rkt")
         (only-in "../L1/flatten.rkt" flatten-program))

(define (block-by-id blocks n)
  (findf (lambda (b) (= n (block-id b))) blocks))

;; ---------------------------------------------------------------------------
;; 指令分类
;; ---------------------------------------------------------------------------

(check-true  (branch-instruction? '(beq t0 t1 L)))
(check-false (branch-instruction? '(add t0 t1 t2)))
(check-true  (jump-instruction? '(jal ra L)))
(check-true  (indirect-instruction? '(jalr ra t0 0)))
(check-true  (trap-instruction? '(ecall)))
(check-true  (trap-instruction? '(ebreak)))

(check-true  (ends-block? '(bne t0 t1 L)))
(check-true  (ends-block? '(jal x0 L)))
(check-true  (ends-block? '(jalr x0 ra 0)))
(check-true  (ends-block? '(ecall)))
(check-false (ends-block? '(add t0 t1 t2)))
(check-false (ends-block? '(lw t0 t1 0)))

;; jal 省略 rd 时按 ra 算 -> 是调用, 不是无条件跳转
(check-true  (unconditional-jump? '(jal x0 L)))
(check-true  (unconditional-jump? '(jal zero L)))
(check-false (unconditional-jump? '(jal ra L)))
(check-false (unconditional-jump? '(jal L)))
(check-equal? (jump-register '(jal x0 L)) 'x0)
(check-equal? (jump-register '(jal L)) 'ra)
(check-equal? (jump-target '(beq t0 t1 L)) 'L)
(check-equal? (jump-target '(jal ra L)) 'L)

;; label 的链: (label a b) 是链 (a b), 不是两个名字
(check-true  (label-form? '(label main)))
(check-true  (label-form? '(label a b)))
(check-false (label-form? '(label)))
(check-false (label-form? '(label (a b))))
(check-false (label-form? '(label #t)))
(check-equal? (label-path '(label main)) '(main))
(check-equal? (label-path '(label a b)) '(a b))

;; 名字/链的类型: symbol / string / number 都行
(check-true (name? 'a))
(check-true (name? "a"))
(check-true (name? 1))
(check-false (name? #t))
(check-true (path? '(a "b" 3)))
(check-false (path? '()))
(check-false (path? '(a (b))))
(check-equal? (normalize-path 'g) '(g))
(check-equal? (normalize-path '(a g)) '(a g))
(check-false (normalize-path #t))
(check-equal? (normalize-path 1.5) '(1.5))

;; 执行会不会顺序落到物理下一条
(check-true  (falls-through? '(add t0 t1 t2)))
(check-true  (falls-through? '(beq t0 t1 (l))))
(check-true  (falls-through? '(jal ra (l))))
(check-false (falls-through? '(jal x0 (l))))
(check-true  (falls-through? '(jalr ra ra 0)))
(check-false (falls-through? '(jalr x0 ra 0)))
(check-true  (falls-through? '(ecall)))
(check-false (falls-through? '(ebreak)))

;; ---------------------------------------------------------------------------
;; 建图
;; ---------------------------------------------------------------------------

;; label 是 leader; ends-block? 之后开新块
(define g1 (cfg:build-cfg '((label a) (add t0 t1 t2) (beq t0 t1 c)
                            (add t1 t1 t1) (label c) (add t2 t2 t2))))
(check-equal? (cfg:cfg-block-count g1) 3)
(check-equal? (cfg:block-labels (vector-ref (cfg:graph-blocks g1) 0)) '((a)))
(check-equal? (cfg:block-insns (vector-ref (cfg:graph-blocks g1) 0))
              '((add t0 t1 t2) (beq t0 t1 c)))
(check-equal? (cfg:block-successors (vector-ref (cfg:graph-blocks g1) 0)) '(2 1))
(check-equal? (cfg:block-successors (vector-ref (cfg:graph-blocks g1) 1)) '(2))
(check-equal? (cfg:block-successors (vector-ref (cfg:graph-blocks g1) 2)) '())

;; 连续的 label 归同一个块(多名字)
(define g2 (cfg:build-cfg '((label a) (label b) (add t0 t1 t2))))
(check-equal? (cfg:cfg-block-count g2) 1)
(check-equal? (cfg:block-labels (vector-ref (cfg:graph-blocks g2) 0)) '((a) (b)))

;; jal x0: 只有目标边
(define g3 (cfg:build-cfg '((label a) (jal x0 c) (label b) (add t0 t0 t0)
                            (label c) (add t1 t1 t1))))
(check-equal? (cfg:block-successors (vector-ref (cfg:graph-blocks g3) 0)) '(2))
(check-false (cfg:graph-indirect? g3))

;; jal ra: 调用, 目标 + 顺序
(define g4 (cfg:build-cfg '((label a) (jal ra c) (label b) (add t0 t0 t0)
                            (label c) (add t1 t1 t1))))
(check-equal? (cfg:block-successors (vector-ref (cfg:graph-blocks g4) 0)) '(2 1))

;; jalr ra = 间接调用: 只有顺序边, 但整张图记为"有间接跳转"
(define g5 (cfg:build-cfg '((label a) (jalr ra ra 0) (label b) (add t0 t0 t0))))
(check-equal? (cfg:block-successors (vector-ref (cfg:graph-blocks g5) 0)) '(1))
(check-true (cfg:graph-indirect? g5))

;; jalr x0 = ret: 不回来, 没有顺序边
(define g5b (cfg:build-cfg '((label a) (jalr x0 ra 0) (label b) (add t0 t0 t0))))
(check-equal? (cfg:block-successors (vector-ref (cfg:graph-blocks g5b) 0)) '())
(check-true (cfg:graph-indirect? g5b))

;; ecall 可能返回, ebreak 停住
(define g6 (cfg:build-cfg '((label a) (ecall) (label b) (add t0 t0 t0))))
(check-equal? (cfg:block-successors (vector-ref (cfg:graph-blocks g6) 0)) '(1))
(define g7 (cfg:build-cfg '((label a) (ebreak) (label b) (add t0 t0 t0))))
(check-equal? (cfg:block-successors (vector-ref (cfg:graph-blocks g7) 0)) '())

;; 不认识的指令: 普通指令, 不切块
(define g8 (cfg:build-cfg '((label a) (frobnicate t0) (add t0 t0 t0))))
(check-equal? (cfg:cfg-block-count g8) 1)

;; 目标 label 不存在时不加边(留给布局层报)
(define g9 (cfg:build-cfg '((label a) (jal x0 nowhere))))
(check-equal? (cfg:block-successors (vector-ref (cfg:graph-blocks g9) 0)) '())

(check-equal? (cfg:referenced-labels '((label a) (jal ra b) (beq t0 t1 c) (add t0 t1 t2)))
              '((b) (c)))
(check-equal? (cfg:referenced-labels '((jal ra (a b)) (jal x0 "s") (jal x0 3)))
              '((a b) ("s") (3)))

;; 地址被取过(不是控制转移目标)
(check-equal? (cfg:address-taken-paths '((label a) (la t0 (b)) (jal x0 (a))))
              '((b)))

;; 可达性
(check-equal? (cfg:cfg-reachable g1 (list 0)) '(0 1 2))
(check-equal? (cfg:cfg-reachable g3 (list 0)) '(0 2))

;; ---------------------------------------------------------------------------
;; 分析: 输出块列表
;; ---------------------------------------------------------------------------

(define blocks (analyze '((label a) (beq t0 t1 c) (add t0 t0 t0) (label c) (add t1 t1 t1))))

(check-equal? (map block-id blocks) '(0 1 2))
(check-equal? (block-labels (block-by-id blocks 0)) '((a)))
(check-equal? (block-labels (block-by-id blocks 1)) '())
(check-equal? (block-labels (block-by-id blocks 2)) '((c)))
(check-equal? (block-insns (block-by-id blocks 0)) '((beq t0 t1 c)))
(check-equal? (block-succ (block-by-id blocks 0)) '(2 1))    ; 分支: 目标 + 顺序
(check-equal? (block-fallthrough (block-by-id blocks 0)) 1)
(check-equal? (block-fallthrough (block-by-id blocks 1)) 2)
(check-false  (block-fallthrough (block-by-id blocks 2)))    ; 末尾块

;; jal x0: 目标块是后继, 但不是顺序后继
(define blocks-jump
  (analyze '((label a) (jal x0 (c)) (label b) (jal x0 (b)) (label c) (add t1 t1 t1))))
(check-equal? (block-succ (block-by-id blocks-jump 0)) '(2))
(check-false  (block-fallthrough (block-by-id blocks-jump 0)))

;; 调用: 目标 + 顺序(返回地址 = pc+4)
(define blocks-call
  (analyze '((label a) (jal ra (c)) (label b) (jal x0 (b)) (label c) (add t1 t1 t1))))
(check-equal? (block-succ (block-by-id blocks-call 0)) '(2 1))
(check-equal? (block-fallthrough (block-by-id blocks-call 0)) 1)

;; 同一位置多个名字
(define blocks-names (analyze '((label a) (label b) (add t0 t0 t0))))
(check-equal? (block-labels (block-by-id blocks-names 0)) '((a) (b)))

;; root? 只有外部入口: 程序入口 / (有间接跳转时)地址被取过
;; 内部分支引用不算根 —— 它在 CFG 里就是边
(check-true (block-root? (block-by-id blocks 0)))            ; 入口
(check-false (block-root? (block-by-id blocks 2)))           ; 被 beq 引用, 但不是外部入口
(check-false (block-root? (block-by-id blocks 1)))

(define blocks-indirect
  (analyze '((label a) (la t0 (b)) (jalr x0 t0 0) (label b) (add t0 t0 t0))))
(check-true (block-root? (block-by-id blocks-indirect 1)))   ; 地址被取过 + 有 jalr

;; 没有被取地址(也没有 jalr)时, 块头的 label 也不是外部入口
(define blocks-no-taken
  (analyze '((label a) (ebreak) (label b) (add t0 t0 t0))))
(check-equal? (map block-id blocks-no-taken) '(0 1))
(check-true  (block-root? (block-by-id blocks-no-taken 0)))   ; 入口
(check-false (block-root? (block-by-id blocks-no-taken 1)))   ; b 不是外部入口

;; 链(label) 模型: 同位置多名 / 任意类型 / 链做跳转目标
(define g-names (cfg:build-cfg '((label a f) (label a g) (jal x0 (a g)))))
(check-equal? (cfg:block-labels (vector-ref (cfg:graph-blocks g-names) 0)) '((a f) (a g)))
(check-equal? (cfg:block-successors (vector-ref (cfg:graph-blocks g-names) 0)) '(0))

(define g-paths (cfg:build-cfg '((label a a) (jal x0 (a b)) (label a b))))
(check-equal? (cfg:block-successors (vector-ref (cfg:graph-blocks g-paths) 0)) '(1))

(define g-typed (cfg:build-cfg '((label "x" 1) (jal x0 ("x" 1)))))
(check-equal? (cfg:block-successors (vector-ref (cfg:graph-blocks g-typed) 0)) '(0))
(define g-num (cfg:build-cfg '((label 1) (jal x0 (1)))))
(check-equal? (cfg:block-successors (vector-ref (cfg:graph-blocks g-num) 0)) '(0))

;; 裸原子当单节链
(define g-bare (cfg:build-cfg '((label g) (jal x0 g))))
(check-equal? (cfg:block-successors (vector-ref (cfg:graph-blocks g-bare) 0)) '(0))

;; L1 展平后的程序直接进 L3
(check-equal? (analyze (flatten-program '((module a (label f) (jal x0 (g)) (label g)))))
              (analyze '((label a f) (jal x0 (a g)) (label a g))))

;; ---------------------------------------------------------------------------
;; 程序形状 / 打印 / 读字面量
;; ---------------------------------------------------------------------------

(check-equal? (program-items '((label a) (add t0 t0 t0)))
              '((label a) (add t0 t0 t0)))
(check-equal? (program-items '(quote ((label a) (add t0 t0 t0))))
              '((label a) (add t0 t0 t0)))
(check-equal? (program-items '(begin (label a) (add t0 t0 t0)))
              '((label a) (add t0 t0 t0)))
(check-equal? (program-items '(add t0 t0 t0)) '((add t0 t0 t0)))

;; blocks <-> sexp 往返
(check-equal? (sexp->blocks (blocks->sexp blocks)) blocks)
(check-equal? (blocks->sexp (analyze '((label a) (add t0 t0 t0))))
              '((block (id 0) (labels (a)) (insns (add t0 t0 t0))
                       (succ) (fallthrough #f) (root? #t))))

;; ---------------------------------------------------------------------------
;; label 不切块: 只有控制流才切
;; ---------------------------------------------------------------------------

;; 非目标 label 只是位置标记, 留在块里
(define blocks-mid (analyze '((label a) (add t0 t0 t0) (label mid) (add t0 t0 t0))))
(check-equal? (map block-id blocks-mid) '(0))
(check-equal? (block-labels (block-by-id blocks-mid 0)) '((a)))
(check-equal? (block-insns (block-by-id blocks-mid 0))
              '((add t0 t0 t0) (label mid) (add t0 t0 t0)))

;; 被跳转的 label 才切块
(define blocks-target (analyze '((label a) (jal x0 (mid))
                                 (label b) (add t0 t0 t0)
                                 (label mid) (add t0 t0 t0))))
(check-equal? (map block-id blocks-target) '(0 1 2))
(check-equal? (block-labels (block-by-id blocks-target 1)) '((b)))
(check-equal? (block-labels (block-by-id blocks-target 2)) '((mid)))

;; 切流指令之后也切块(即使没有 label)
(define blocks-after-branch (analyze '((label a) (beq t0 t1 (a)) (add t0 t0 t0))))
(check-equal? (map block-id blocks-after-branch) '(0 1))
(check-equal? (block-labels (block-by-id blocks-after-branch 1)) '())

(displayln "L3 tests: ok")
