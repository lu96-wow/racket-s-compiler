#lang racket
;;; L3/test.rkt

(require rackunit
         "insn.rkt"
         "cfg.rkt"
         "opt.rkt"
         (only-in "../L1/flatten.rkt" flatten-program))

;; ---- 测试用视图 ------------------------------------------------------------

;; 块列表 -> 扁平 item(大部分语义测试只看内容)
(define (flat blocks)
  (append*
   (for/list ([b (in-list blocks)])
     (append (for/list ([l (in-list (cdr (assoc 'labels (cdr b))))])
               (cons 'label l))
             (cdr (assoc 'insns (cdr b)))))))

(define (opt items) (flat (optimize-program items)))

(define (block-by-id blocks n)
  (findf (lambda (b) (= n (cadr (assoc 'id (cdr b))))) blocks))
(define (block-labels* b) (cdr (assoc 'labels (cdr b))))
(define (block-insns* b) (cdr (assoc 'insns (cdr b))))
(define (block-succ* b) (cdr (assoc 'succ (cdr b))))
(define (block-ft* b) (cadr (assoc 'fallthrough (cdr b))))

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
;; 裸原子当单节链
(check-equal? (normalize-path 'g) '(g))
(check-equal? (normalize-path '(a g)) '(a g))
(check-false (normalize-path #t))
(check-equal? (normalize-path 1.5) '(1.5))

;; ---------------------------------------------------------------------------
;; 建图
;; ---------------------------------------------------------------------------

;; label 是 leader; ends-block? 之后开新块
(define g1 (build-cfg '((label a) (add t0 t1 t2) (beq t0 t1 c)
                        (add t1 t1 t1) (label c) (add t2 t2 t2))))
(check-equal? (cfg-block-count g1) 3)
(check-equal? (block-labels (vector-ref (graph-blocks g1) 0)) '((a)))
(check-equal? (block-insns  (vector-ref (graph-blocks g1) 0))
              '((add t0 t1 t2) (beq t0 t1 c)))
;; 分支: 目标 + 顺序
(check-equal? (block-successors (vector-ref (graph-blocks g1) 0)) '(2 1))
(check-equal? (block-successors (vector-ref (graph-blocks g1) 1)) '(2))
(check-equal? (block-successors (vector-ref (graph-blocks g1) 2)) '())

;; 连续的 label 归同一个块
(define g2 (build-cfg '((label a) (label b) (add t0 t1 t2))))
(check-equal? (cfg-block-count g2) 1)
;; 同位置的多个名字 = 多条链, 都归这个块
(check-equal? (block-labels (vector-ref (graph-blocks g2) 0)) '((a) (b)))

;; jal x0: 只有目标边, 没有顺序边
(define g3 (build-cfg '((label a) (jal x0 c) (label b) (add t0 t0 t0)
                        (label c) (add t1 t1 t1))))
(check-equal? (block-successors (vector-ref (graph-blocks g3) 0)) '(2))
(check-false (graph-indirect? g3))

;; jal ra: 调用, 目标 + 顺序
(define g4 (build-cfg '((label a) (jal ra c) (label b) (add t0 t0 t0)
                        (label c) (add t1 t1 t1))))
(check-equal? (block-successors (vector-ref (graph-blocks g4) 0)) '(2 1))

;; jalr ra = 间接调用: 目标不可知 -> 只有顺序边, 但整张图记为"有间接跳转"
(define g5 (build-cfg '((label a) (jalr ra ra 0) (label b) (add t0 t0 t0))))
(check-equal? (block-successors (vector-ref (graph-blocks g5) 0)) '(1))
(check-true (graph-indirect? g5))

;; jalr x0 = ret: 不回来, 没有顺序边
(define g5b (build-cfg '((label a) (jalr x0 ra 0) (label b) (add t0 t0 t0))))
(check-equal? (block-successors (vector-ref (graph-blocks g5b) 0)) '())
(check-true (graph-indirect? g5b))

;; falls-through? 一览
(check-true  (falls-through? '(add t0 t1 t2)))
(check-true  (falls-through? '(beq t0 t1 (l))))
(check-true  (falls-through? '(jal ra (l))))
(check-false (falls-through? '(jal x0 (l))))
(check-true  (falls-through? '(jalr ra ra 0)))
(check-false (falls-through? '(jalr x0 ra 0)))
(check-true  (falls-through? '(ecall)))
(check-false (falls-through? '(ebreak)))

;; ecall 可能返回, ebreak 停住
(define g6 (build-cfg '((label a) (ecall) (label b) (add t0 t0 t0))))
(check-equal? (block-successors (vector-ref (graph-blocks g6) 0)) '(1))
(define g7 (build-cfg '((label a) (ebreak) (label b) (add t0 t0 t0))))
(check-equal? (block-successors (vector-ref (graph-blocks g7) 0)) '())

;; 不认识的指令: 普通指令, 不切块
(define g8 (build-cfg '((label a) (frobnicate t0) (add t0 t0 t0))))
(check-equal? (cfg-block-count g8) 1)

;; 目标 label 不存在时不加边(留给后面报错)
(define g9 (build-cfg '((label a) (jal x0 nowhere))))
(check-equal? (block-successors (vector-ref (graph-blocks g9) 0)) '())

(check-equal? (referenced-labels '((label a) (jal ra b) (beq t0 t1 c) (add t0 t1 t2)))
              '((b) (c)))

;; 目标写成链也一样(支持任意类型)
(check-equal? (referenced-labels '((jal ra (a b)) (jal x0 "s") (jal x0 3)))
              '((a b) ("s") (3)))

;; ---------------------------------------------------------------------------
;; 可达性
;; ---------------------------------------------------------------------------

(check-equal? (cfg-reachable g1 (list 0)) '(0 1 2))
(check-equal? (cfg-reachable g3 (list 0)) '(0 2))

;; ---------------------------------------------------------------------------
;; 优化: 删不可达块
;; ---------------------------------------------------------------------------

;; jal x0 之后、且没人跳过去的块 -> 删(含它的 label)
(check-equal? (opt
               '((label start) (add t0 t1 t2) (jal x0 done)
                 (label dead) (add t3 t4 t5)
                 (label done) (add t0 t0 t0)))
              '((label start) (add t0 t1 t2) (label done) (add t0 t0 t0)))

;; 有间接跳转, 但 b 既没被直接引用、地址也没被取过 -> 仍然不可达
;; (ret 之后那块也走不到, 一起删)
(check-equal? (opt
               '((label a) (jalr x0 ra 0) (jal x0 a) (label b) (add t0 t0 t0)))
              '((label a) (jalr x0 ra 0)))

;; 有间接跳转 + b 的地址被取过(la) -> 可能被跳到, 保留
(check-equal? (opt
               '((label a) (la t0 (b)) (jalr x0 ra 0) (jal x0 a)
                 (label b) (add t0 t0 t0)))
              '((label a) (la t0 (b)) (jalr x0 ra 0) (label b) (add t0 t0 t0)))

;; 有间接跳转 + b 被分支直接引用 -> 保留
(check-equal? (opt
               '((label a) (jalr x0 ra 0) (beq t0 t1 (b))
                 (label c) (add t0 t0 t0)
                 (label b) (add t1 t1 t1)))
              '((label a) (jalr x0 ra 0) (label b) (add t1 t1 t1)))

;; 同样的形状, 没有间接跳转 -> 无名块之后的 b 走不到, 删掉
(check-equal? (opt
               '((label a) (add t0 t0 t0) (jal x0 a) (label b) (add t1 t1 t1)))
              '((label a) (add t0 t0 t0) (jal x0 a)))

;; 调用会回来, jal ra 之后的代码保留
(check-equal? (opt
               '((label a) (jal ra f) (add t0 t0 t0)))
              '((label a) (jal ra f) (add t0 t0 t0)))

;; ebreak 之后到不了
(check-equal? (opt '((label a) (ebreak) (add t0 t0 t0)))
              '((label a) (ebreak)))

;; ecall 之后可能回来, 保留
(check-equal? (opt '((label a) (ecall) (add t0 t0 t0)))
              '((label a) (ecall) (add t0 t0 t0)))

;; 回边不会误删循环体
(check-equal? (opt
               '((label top) (addi t0 t0 1) (blt t0 t1 top)
                 (label end) (add t1 t1 t1)))
              '((label top) (addi t0 t0 1) (blt t0 t1 top)
                       (label end) (add t1 t1 t1)))

;; ---------------------------------------------------------------------------
;; 优化: 转移到紧邻下一块
;; ---------------------------------------------------------------------------

;; jal x0 到下一块的 label -> 删跳转
(check-equal? (opt '((label a) (add t0 t0 t0) (jal x0 b) (label b) (add t1 t1 t1)))
              '((label a) (add t0 t0 t0) (label b) (add t1 t1 t1)))

;; 分支到下一块的 label -> 两种走向一样, 删分支
(check-equal? (opt '((label a) (beq t0 t1 b) (label b) (add t0 t0 t0)))
              '((label a) (label b) (add t0 t0 t0)))

;; 目标不是紧邻下一块 -> 不动
(check-equal? (opt
               '((label a) (beq t0 t1 c) (add t0 t0 t0) (label c) (add t1 t1 t1)))
              '((label a) (beq t0 t1 c) (add t0 t0 t0) (label c) (add t1 t1 t1)))

;; 调用 (jal ra) 即使目标是下一块也不能删: 它还承担"把返回地址写进 ra"
(check-equal? (opt '((label a) (jal ra b) (label b) (add t0 t0 t0)))
              '((label a) (jal ra b) (label b) (add t0 t0 t0)))

;; 代码里没有屏障概念了: 数据在独立输入里, 由 L4 用 code-data-mixed 报。
;; 这里只确认: 不认识的 item 当普通 item, 不参与控制流。
(check-equal? (opt '((label a) (bytes 1 2 3) (label b) (add t0 t0 t0)))
              '((label a) (bytes 1 2 3) (label b) (add t0 t0 t0)))

;; ---------------------------------------------------------------------------
;; 优化: 转移到紧邻下一块
;; ---------------------------------------------------------------------------

;; jal x0 到下一块的 label -> 删跳转
(check-equal? (opt '((label a) (add t0 t0 t0) (jal x0 b) (label b) (add t1 t1 t1)))
              '((label a) (add t0 t0 t0) (label b) (add t1 t1 t1)))

;; 分支到下一块的 label -> 两种走向一样, 删分支
(check-equal? (opt '((label a) (beq t0 t1 b) (label b) (add t0 t0 t0)))
              '((label a) (label b) (add t0 t0 t0)))

;; 目标不是紧邻下一块 -> 不动
(check-equal? (opt
               '((label a) (beq t0 t1 c) (add t0 t0 t0) (label c) (add t1 t1 t1)))
              '((label a) (beq t0 t1 c) (add t0 t0 t0) (label c) (add t1 t1 t1)))

;; 调用 (jal ra) 即使目标是下一块也不能删: 它还承担"把返回地址写进 ra"
(check-equal? (opt '((label a) (jal ra b) (label b) (add t0 t0 t0)))
              '((label a) (jal ra b) (label b) (add t0 t0 t0)))

;; 代码里没有屏障概念了: 数据在独立输入里, 由 L4 用 code-data-mixed 报。
;; 这里只确认: 不认识的 item 当普通 item, 不参与控制流。
(check-equal? (opt '((label a) (bytes 1 2 3) (label b) (add t0 t0 t0)))
              '((label a) (bytes 1 2 3) (label b) (add t0 t0 t0)))

;; ---------------------------------------------------------------------------
;; 形状 / 幂等 / 透传
;; ---------------------------------------------------------------------------

;; 进 list, 出也一定是 list (而且不再是 quote/begin 壳)
(check-true (list? (opt '((label a) (add t0 t1 t2)))))
(check-equal? (opt '((label a) (add t0 t1 t2)))
              '((label a) (add t0 t1 t2)))

;; 幂等
(define once (opt '((label a) (jal x0 c) (label b) (add t0 t0 t0)
                                 (label c) (add t1 t1 t1))))
(check-equal? (opt once) once)

;; 不认识的指令原样保留, 不影响分析
(check-equal? (opt '((label a) (frobnicate t0) (add t0 t0 t0)))
              '((label a) (frobnicate t0) (add t0 t0 t0)))

;; ---------------------------------------------------------------------------
;; 链(label) 模型: 同位置多名 / 任意类型 / 链做跳转目标
;; ---------------------------------------------------------------------------

;; 连续 label = 同一位置, 两个名字
(define g-names (build-cfg '((label a f) (label a g) (jal x0 (a g)))))
(check-equal? (cfg-block-count g-names) 1)
(check-equal? (block-labels (vector-ref (graph-blocks g-names) 0)) '((a f) (a g)))
(check-equal? (block-successors (vector-ref (graph-blocks g-names) 0)) '(0))

;; 链不同就是不同位置: (a a) 与 (a b)
(define g-paths (build-cfg '((label a a) (jal x0 (a b)) (label a b))))
(check-equal? (block-successors (vector-ref (graph-blocks g-paths) 0)) '(1))

;; 字符串 / 数字名字
(define g-typed (build-cfg '((label "x" 1) (jal x0 ("x" 1)))))
(check-equal? (block-successors (vector-ref (graph-blocks g-typed) 0)) '(0))
(define g-num (build-cfg '((label 1) (jal x0 (1)))))
(check-equal? (block-successors (vector-ref (graph-blocks g-num) 0)) '(0))

;; 目标是裸原子: 等价于单节链
(define g-bare (build-cfg '((label g) (jal x0 g))))
(check-equal? (block-successors (vector-ref (graph-blocks g-bare) 0)) '(0))

;; L1 展平后的程序直接进 L3
(define flat-prog (flatten-program '((module a (label f) (jal x0 (g)) (label g)))))
(check-equal? flat-prog
              '((label a f) (jal x0 (a g)) (label a g)))
(check-equal? (opt flat-prog)
              '((label a f) (label a g)))

;; ---------------------------------------------------------------------------
;; 程序形状: 普通 list, 旧壳 (quote ...)/(begin ...) 也收
;; ---------------------------------------------------------------------------

(check-equal? (program-items '((label a) (add t0 t0 t0)))
              '((label a) (add t0 t0 t0)))
(check-equal? (program-items '(quote ((label a) (add t0 t0 t0))))
              '((label a) (add t0 t0 t0)))
(check-equal? (program-items '(begin (label a) (add t0 t0 t0)))
              '((label a) (add t0 t0 t0)))
(check-equal? (program-items '(add t0 t0 t0)) '((add t0 t0 t0)))

;; 出口一律 plain list
(check-equal? (opt '((label a) (jal x0 b) (label b)))
              '((label a) (label b)))

;; begin 不当指令: 一块, 只有 1 条指令
(define g-begin (build-cfg (program-items '(begin (label a) (add t0 t0 t0)))))
(check-equal? (cfg-block-count g-begin) 1)
(check-equal? (block-insns (vector-ref (graph-blocks g-begin) 0)) '((add t0 t0 t0)))

;; 不带 begin 的裸列表: 出去也不带
(check-equal? (opt '((label a) (add t0 t0 t0)))
              '((label a) (add t0 t0 t0)))

;; pass 名字反映功能
(check-equal? (pass-names) '(drop-unreachable drop-transfers-to-next-block))

;; ---------------------------------------------------------------------------
;; 输出块: id / labels / insns / succ / fallthrough
;; ---------------------------------------------------------------------------

(define blocks
  (optimize-program '((label a) (beq t0 t1 c) (add t0 t0 t0) (label c) (add t1 t1 t1))))

(check-equal? (map (lambda (b) (cadr (assoc 'id (cdr b)))) blocks) '(0 1 2))
(check-equal? (block-labels* (block-by-id blocks 0)) '((a)))
(check-equal? (block-labels* (block-by-id blocks 1)) '())
(check-equal? (block-labels* (block-by-id blocks 2)) '((c)))
(check-equal? (block-succ* (block-by-id blocks 0)) '(2 1))   ; 分支: 目标 + 顺序
(check-equal? (block-ft*   (block-by-id blocks 0)) 1)
(check-equal? (block-ft*   (block-by-id blocks 1)) 2)
(check-false  (block-ft*   (block-by-id blocks 2)))          ; 末尾块

;; jal x0: 目标块是后继, 但不是顺序后继
;; (让 b 自引用, 否则它不可达会被 L3 删掉, jal 也会被当成"跳到紧邻下一块"删掉)
(define blocks-jump
  (optimize-program '((label a) (jal x0 (c)) (label b) (jal x0 (b)) (label c) (add t1 t1 t1))))
(check-equal? (block-succ* (block-by-id blocks-jump 0)) '(2))
(check-false  (block-ft*   (block-by-id blocks-jump 0)))

;; 调用: 目标 + 顺序
(define blocks-call
  (optimize-program '((label a) (jal ra (c)) (label b) (jal x0 (b)) (label c) (add t1 t1 t1))))
(check-equal? (block-succ* (block-by-id blocks-call 0)) '(2 1))
(check-equal? (block-ft*   (block-by-id blocks-call 0)) 1)

;; 同一位置多个名字: 都进同一个块的 labels
(define blocks-names (optimize-program '((label a) (label b) (add t0 t0 t0))))
(check-equal? (block-labels* (block-by-id blocks-names 0)) '((a) (b)))

(displayln "L3 tests: ok")
