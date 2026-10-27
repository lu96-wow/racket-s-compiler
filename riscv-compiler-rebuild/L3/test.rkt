#lang racket
;;; L3/test.rkt -- 控制流分析(只分析, 不改程序)

(require rackunit
         "insn.rkt"
         "analyze.rkt"
         (prefix-in cfg: "cfg.rkt")
         (only-in "../L1/flatten.rkt" flatten-program))

;; 块下标就是它在列表里的位置
(define (block-at blocks n) (list-ref blocks n))
(define (flow-at flows n) (list-ref flows n))
(define (analyze-blocks items) (program-blocks (analyze items)))
(define (analyze-flows items) (program-flows (analyze items)))

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

;; 远形式也在控制流里: link 显式写出来, 所以"落不落下"可算
(check-true  (branch-instruction? '(branch-far t0 t1 L)))
(check-true  (branch-instruction? '(branch-indirect s t0 t1 L)))
(check-true  (branch-instruction? '(branch-indirect t0 t1 L)))     ; 空槽也算分支
(check-false (branch-instruction? '(add t0 t1 t2)))
(check-true  (jump-instruction? '(jump-far ra L)))
(check-false (jump-instruction? '(call-far (L))))                  ; 已删: 就是 jump-far ra
(check-true  (ends-block? '(jump-far x0 L)))
(check-true  (ends-block? '(branch-far t0 t1 L)))
(check-equal? (jump-register '(jump-far ra L)) 'ra)
(check-equal? (jump-register '(jump-far x0 L)) 'x0)
(check-equal? (jump-register '(jump-far 0 L)) 0)
(check-true  (falls-through? '(jump-far ra L)))     ; 调用: 返回地址 = pc+4
(check-false (falls-through? '(jump-far x0 L)))     ; 跳转: 不回来
(check-false (falls-through? '(jump-far zero L)))
(check-true  (unconditional-jump? '(jump-far x0 L)))
(check-false (unconditional-jump? '(jump-far ra L)))
(check-true  (falls-through? '(branch-far t0 t1 L)))
(check-true  (falls-through? '(branch-indirect s t0 t1 L)))
(check-equal? (jump-target '(branch-far t0 t1 L)) 'L)
(check-equal? (jump-target '(jump-far ra L)) 'L)
(check-equal? (jump-target '(branch-indirect s t0 t1 L)) 'L)

;; 压缩形式: 分类与展开形式一致
(check-true  (branch-instruction? '(c.beqz a L)))
(check-true  (branch-instruction? '(c.bnez a L)))
(check-false (branch-instruction? '(c.addi a 1)))
(check-true  (jump-instruction? '(c.j L)))
(check-true  (jump-instruction? '(c.jal L)))
(check-true  (indirect-instruction? '(c.jr ra)))
(check-true  (indirect-instruction? '(c.jalr ra)))
(check-true  (trap-instruction? '(c.ebreak)))
(check-true  (ends-block? '(c.j L)))
(check-true  (ends-block? '(c.jr ra)))
(check-false (ends-block? '(c.addi a 1)))
(check-equal? (jump-target '(c.beqz a L)) 'L)
(check-equal? (jump-target '(c.jal L)) 'L)

;; c.j/c.jr 不写链接寄存器(等于 x0); c.jal/c.jalr 写 ra
(check-equal? (jump-register '(c.j L)) 'x0)
(check-equal? (jump-register '(c.jr ra)) 'x0)
(check-equal? (jump-register '(c.jal L)) 'ra)
(check-equal? (jump-register '(c.jalr ra)) 'ra)
(check-true  (unconditional-jump? '(c.j L)))
(check-false (unconditional-jump? '(c.jal L)))
(check-false (falls-through? '(c.j L)))
(check-true  (falls-through? '(c.jal L)))
(check-false (falls-through? '(c.jr ra)))
(check-true  (falls-through? '(c.jalr ra)))
(check-false (falls-through? '(c.ebreak)))

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
(check-equal? (cfg:basic-block-labels (vector-ref (cfg:graph-blocks g1) 0)) '((a)))
(check-equal? (cfg:basic-block-items (vector-ref (cfg:graph-blocks g1) 0))
              '((add t0 t1 t2) (beq t0 t1 c)))
(check-equal? (cfg:basic-block-successors (vector-ref (cfg:graph-blocks g1) 0)) '(2 1))
(check-equal? (cfg:basic-block-successors (vector-ref (cfg:graph-blocks g1) 1)) '(2))
(check-equal? (cfg:basic-block-successors (vector-ref (cfg:graph-blocks g1) 2)) '())

;; 连续的 label 归同一个块(多名字)
(define g2 (cfg:build-cfg '((label a) (label b) (add t0 t1 t2))))
(check-equal? (cfg:cfg-block-count g2) 1)
(check-equal? (cfg:basic-block-labels (vector-ref (cfg:graph-blocks g2) 0)) '((a) (b)))

;; jal x0: 只有目标边
(define g3 (cfg:build-cfg '((label a) (jal x0 c) (label b) (add t0 t0 t0)
                            (label c) (add t1 t1 t1))))
(check-equal? (cfg:basic-block-successors (vector-ref (cfg:graph-blocks g3) 0)) '(2))
(check-false (cfg:graph-indirect? g3))

;; jal ra: 调用, 目标 + 顺序
(define g4 (cfg:build-cfg '((label a) (jal ra c) (label b) (add t0 t0 t0)
                            (label c) (add t1 t1 t1))))
(check-equal? (cfg:basic-block-successors (vector-ref (cfg:graph-blocks g4) 0)) '(2 1))

;; jalr ra = 间接调用: 只有顺序边, 但整张图记为"有间接跳转"
(define g5 (cfg:build-cfg '((label a) (jalr ra ra 0) (label b) (add t0 t0 t0))))
(check-equal? (cfg:basic-block-successors (vector-ref (cfg:graph-blocks g5) 0)) '(1))
(check-true (cfg:graph-indirect? g5))

;; jalr x0 = ret: 不回来, 没有顺序边
(define g5b (cfg:build-cfg '((label a) (jalr x0 ra 0) (label b) (add t0 t0 t0))))
(check-equal? (cfg:basic-block-successors (vector-ref (cfg:graph-blocks g5b) 0)) '())
(check-true (cfg:graph-indirect? g5b))

;; ecall 可能返回, ebreak 停住
(define g6 (cfg:build-cfg '((label a) (ecall) (label b) (add t0 t0 t0))))
(check-equal? (cfg:basic-block-successors (vector-ref (cfg:graph-blocks g6) 0)) '(1))
(define g7 (cfg:build-cfg '((label a) (ebreak) (label b) (add t0 t0 t0))))
(check-equal? (cfg:basic-block-successors (vector-ref (cfg:graph-blocks g7) 0)) '())

;; 压缩控制转移: 同样切块、同样有边
(define gc1 (cfg:build-cfg '((label a) (c.beqz t0 c) (label b) (add t0 t0 t0)
                             (label c) (add t1 t1 t1))))
(check-equal? (cfg:basic-block-successors (vector-ref (cfg:graph-blocks gc1) 0)) '(2 1))

(define gc2 (cfg:build-cfg '((label a) (c.j c) (label b) (add t0 t0 t0)
                            (label c) (add t1 t1 t1))))
(check-equal? (cfg:basic-block-successors (vector-ref (cfg:graph-blocks gc2) 0)) '(2))

(define gc3 (cfg:build-cfg '((label a) (c.jr ra) (label b) (add t0 t0 t0))))
(check-equal? (cfg:basic-block-successors (vector-ref (cfg:graph-blocks gc3) 0)) '())
(check-true (cfg:graph-indirect? gc3))

(define gc4 (cfg:build-cfg '((label a) (c.jalr ra) (label b) (add t0 t0 t0))))
(check-equal? (cfg:basic-block-successors (vector-ref (cfg:graph-blocks gc4) 0)) '(1))

(define gc5 (cfg:build-cfg '((label a) (c.ebreak) (label b) (add t0 t0 t0))))
(check-equal? (cfg:basic-block-successors (vector-ref (cfg:graph-blocks gc5) 0)) '())

;; 压缩分支目标也算引用
(check-equal? (cfg:referenced-labels '((c.j (c)) (c.beqz t0 (d))))
              '((c) (d)))

;; 不认识的指令: 普通指令, 不切块
(define g8 (cfg:build-cfg '((label a) (frobnicate t0) (add t0 t0 t0))))
(check-equal? (cfg:cfg-block-count g8) 1)

;; 目标 label 不存在时不加边(留给布局层报)
(define g9 (cfg:build-cfg '((label a) (jal x0 nowhere))))
(check-equal? (cfg:basic-block-successors (vector-ref (cfg:graph-blocks g9) 0)) '())

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

(define prog (analyze '((label a) (beq t0 t1 c) (add t0 t0 t0) (label c) (add t1 t1 t1))))
(define blocks (program-blocks prog))
(define flows (program-flows prog))

(check-equal? (range (length blocks)) '(0 1 2))
(check-equal? (block-head (block-at blocks 0)) '((a)))
(check-equal? (block-head (block-at blocks 1)) '())
(check-equal? (block-head (block-at blocks 2)) '((c)))
(check-equal? (block-items (block-at blocks 0)) '((beq t0 t1 c)))
(check-equal? (flow-succ (flow-at flows 0)) '(2 1))    ; 分支: 目标 + 顺序
(check-equal? (flow-fallthrough (flow-at flows 0)) 1)
(check-equal? (flow-fallthrough (flow-at flows 1)) 2)
(check-false  (flow-fallthrough (flow-at flows 2)))    ; 末尾块

;; jal x0: 目标块是后继, 但不是顺序后继
(define blocks-jump
  (analyze '((label a) (jal x0 (c)) (label b) (jal x0 (b)) (label c) (add t1 t1 t1))))
(check-equal? (flow-succ (flow-at (program-flows blocks-jump) 0)) '(2))
(check-false  (flow-fallthrough (flow-at (program-flows blocks-jump) 0)))

;; 调用: 目标 + 顺序(返回地址 = pc+4)
(define blocks-call
  (analyze '((label a) (jal ra (c)) (label b) (jal x0 (b)) (label c) (add t1 t1 t1))))
(check-equal? (flow-succ (flow-at (program-flows blocks-call) 0)) '(2 1))
(check-equal? (flow-fallthrough (flow-at (program-flows blocks-call) 0)) 1)

;; 远跳转的块边界: (jump-far x0 L) 之后开新块, 且没有顺序边
(define blocks-far-jump
  (analyze '((label a) (jump-far x0 (c)) (label b) (add t0 t0 t0) (label c) (add t1 t1 t1))))
(check-equal? (map block-head (program-blocks blocks-far-jump)) '(((a)) ((b)) ((c))))
(check-equal? (flow-succ (flow-at (program-flows blocks-far-jump) 0)) '(2))
(check-false  (flow-fallthrough (flow-at (program-flows blocks-far-jump) 0)))

;; (jump-far ra L) 是调用: 目标 + 顺序
(define blocks-far-call
  (analyze '((label a) (jump-far ra (c)) (label b) (add t0 t0 t0) (label c) (add t1 t1 t1))))
(check-equal? (flow-succ (flow-at (program-flows blocks-far-call) 0)) '(2 1))
(check-equal? (flow-fallthrough (flow-at (program-flows blocks-far-call) 0)) 1)

;; 同一位置多个名字
(define blocks-names (analyze '((label a) (label b) (add t0 t0 t0))))
(check-equal? (block-head (block-at (program-blocks blocks-names) 0)) '((a) (b)))

;; root? 只有外部入口: 程序入口 / (有间接跳转时)地址被取过
;; 内部分支引用不算根 —— 它在 CFG 里就是边
(check-true (flow-root? (flow-at flows 0)))                  ; 入口
(check-false (flow-root? (flow-at flows 2)))                 ; 被 beq 引用, 但不是外部入口
(check-false (flow-root? (flow-at flows 1)))

(define blocks-indirect
  (analyze '((label a) (la t0 (b)) (jalr x0 t0 0) (label b) (add t0 t0 t0))))
(check-true (flow-root? (flow-at (program-flows blocks-indirect) 1)))   ; 地址被取过 + 有 jalr

;; 数据里的地址字也算"取过地址": 函数指针表 / 跳转表
(define items-with-jalr '((label a) (jalr x0 t0 0) (label b) (add t0 t0 t0)))
(define no-data (analyze items-with-jalr))
(define with-data (analyze items-with-jalr
                           '((label d tbl) (value 8 (label+ (b) 0)))))
(check-false (flow-root? (flow-at (program-flows no-data) 1)))
(check-true  (flow-root? (flow-at (program-flows with-data) 1)))

;; 数据 item 只贡献 roots, 不进 CFG
(check-equal? (length (program-blocks with-data)) 2)

;; 没有间接跳转时, 数据里的地址不会凭空造出 root
(check-false (flow-root?
              (flow-at (program-flows
                        (analyze '((label a) (jal x0 (b)) (label b) (add t1 t1 t1))
                                 '((value 8 (label+ (b) 0)))))
                       1)))

;; 没有被取地址(也没有 jalr)时, 块头的 label 也不是外部入口
(define blocks-no-taken
  (analyze '((label a) (ebreak) (label b) (add t0 t0 t0))))
(check-equal? (range (length (program-blocks blocks-no-taken))) '(0 1))
(check-true  (flow-root? (flow-at (program-flows blocks-no-taken) 0)))   ; 入口
(check-false (flow-root? (flow-at (program-flows blocks-no-taken) 1)))   ; b 不是外部入口

;; 链(label) 模型: 同位置多名 / 任意类型 / 链做跳转目标
(define g-names (cfg:build-cfg '((label a f) (label a g) (jal x0 (a g)))))
(check-equal? (cfg:basic-block-labels (vector-ref (cfg:graph-blocks g-names) 0)) '((a f) (a g)))
(check-equal? (cfg:basic-block-successors (vector-ref (cfg:graph-blocks g-names) 0)) '(0))

(define g-paths (cfg:build-cfg '((label a a) (jal x0 (a b)) (label a b))))
(check-equal? (cfg:basic-block-successors (vector-ref (cfg:graph-blocks g-paths) 0)) '(1))

(define g-typed (cfg:build-cfg '((label "x" 1) (jal x0 ("x" 1)))))
(check-equal? (cfg:basic-block-successors (vector-ref (cfg:graph-blocks g-typed) 0)) '(0))
(define g-num (cfg:build-cfg '((label 1) (jal x0 (1)))))
(check-equal? (cfg:basic-block-successors (vector-ref (cfg:graph-blocks g-num) 0)) '(0))

;; 裸原子当单节链
(define g-bare (cfg:build-cfg '((label g) (jal x0 g))))
(check-equal? (cfg:basic-block-successors (vector-ref (cfg:graph-blocks g-bare) 0)) '(0))

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

(check-equal? (program-blocks (analyze '((label a) (add t0 t0 t0))))
              '((block ((a)) (add t0 t0 t0))))
(check-equal? (program-flows (analyze '((label a) (add t0 t0 t0))))
              '((flow (succ) (fallthrough #f) (root? #t))))
;; program <-> sexp 往返; 输出就是字段表, 没有 (program ...) 壳
(check-equal? (program->sexp prog)
              '((blocks (block ((a)) (beq t0 t1 c))
                        (block () (add t0 t0 t0))
                        (block ((c)) (add t1 t1 t1)))
                (flows (flow (succ 2 1) (fallthrough 1) (root? #t))
                       (flow (succ 2) (fallthrough 2) (root? #f))
                       (flow (succ) (fallthrough #f) (root? #f)))))
(check-equal? (sexp->program (program->sexp prog)) prog)
;; 带 (program ...) 壳的旧写法不再接受
(check-exn exn:fail? (lambda () (sexp->program (cons 'program (program->sexp prog)))))

;; ---------------------------------------------------------------------------
;; label 不切块: 只有控制流才切
;; ---------------------------------------------------------------------------

;; 非目标 label 只是位置标记, 留在块里
(define blocks-mid (analyze '((label a) (add t0 t0 t0) (label mid) (add t0 t0 t0))))
(check-equal? (range (length (program-blocks blocks-mid))) '(0))
(check-equal? (block-head (block-at (program-blocks blocks-mid) 0)) '((a)))
(check-equal? (block-items (block-at (program-blocks blocks-mid) 0))
              '((add t0 t0 t0) (label mid) (add t0 t0 t0)))

;; 被跳转的 label 才切块
(define blocks-target (analyze '((label a) (jal x0 (mid))
                                 (label b) (add t0 t0 t0)
                                 (label mid) (add t0 t0 t0))))
(check-equal? (range (length (program-blocks blocks-target))) '(0 1 2))
(check-equal? (block-head (block-at (program-blocks blocks-target) 1)) '((b)))
(check-equal? (block-head (block-at (program-blocks blocks-target) 2)) '((mid)))

;; 切流指令之后也切块(即使没有 label)
(define blocks-after-branch (analyze '((label a) (beq t0 t1 (a)) (add t0 t0 t0))))
(check-equal? (range (length (program-blocks blocks-after-branch))) '(0 1))
(check-equal? (block-head (block-at (program-blocks blocks-after-branch) 1)) '())

(displayln "L3 tests: ok")
