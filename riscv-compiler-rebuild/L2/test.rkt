#lang racket
;;; L2/test.rkt

(require rackunit
         "insn.rkt"
         "cfg.rkt"
         "opt.rkt")

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

(check-true  (label-form? '(label main)))
(check-false (label-form? '(label)))
(check-false (label-form? '(label a b)))
(check-equal? (label-name '(label main)) 'main)

(check-true  (barrier-form? '(section text)))
(check-true  (barrier-form? '(bytes 1 2 3)))
(check-true  (barrier-form? '(align 8)))
(check-false (barrier-form? '(label main)))
(check-false (barrier-form? '(add t0 t1 t2)))

;; ---------------------------------------------------------------------------
;; 建图
;; ---------------------------------------------------------------------------

;; label 是 leader; ends-block? 之后开新块
(define g1 (build-cfg '((label a) (add t0 t1 t2) (beq t0 t1 c)
                        (add t1 t1 t1) (label c) (add t2 t2 t2))))
(check-equal? (cfg-block-count g1) 3)
(check-equal? (block-labels (vector-ref (graph-blocks g1) 0)) '(a))
(check-equal? (block-insns  (vector-ref (graph-blocks g1) 0))
              '((add t0 t1 t2) (beq t0 t1 c)))
;; 分支: 目标 + 顺序
(check-equal? (block-successors (vector-ref (graph-blocks g1) 0)) '(2 1))
(check-equal? (block-successors (vector-ref (graph-blocks g1) 1)) '(2))
(check-equal? (block-successors (vector-ref (graph-blocks g1) 2)) '())

;; 连续的 label 归同一个块
(define g2 (build-cfg '((label a) (label b) (add t0 t1 t2))))
(check-equal? (cfg-block-count g2) 1)
(check-equal? (block-labels (vector-ref (graph-blocks g2) 0)) '(a b))

;; jal x0: 只有目标边, 没有顺序边
(define g3 (build-cfg '((label a) (jal x0 c) (label b) (add t0 t0 t0)
                        (label c) (add t1 t1 t1))))
(check-equal? (block-successors (vector-ref (graph-blocks g3) 0)) '(2))
(check-false (graph-indirect? g3))

;; jal ra: 调用, 目标 + 顺序
(define g4 (build-cfg '((label a) (jal ra c) (label b) (add t0 t0 t0)
                        (label c) (add t1 t1 t1))))
(check-equal? (block-successors (vector-ref (graph-blocks g4) 0)) '(2 1))

;; jalr: 目标不可知 -> 只有顺序边, 但整张图记为"有间接跳转"
(define g5 (build-cfg '((label a) (jalr x0 ra 0) (label b) (add t0 t0 t0))))
(check-equal? (block-successors (vector-ref (graph-blocks g5) 0)) '(1))
(check-true (graph-indirect? g5))

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
              '(b c))

;; ---------------------------------------------------------------------------
;; 可达性
;; ---------------------------------------------------------------------------

(check-equal? (cfg-reachable g1 (list 0)) '(0 1 2))
(check-equal? (cfg-reachable g3 (list 0)) '(0 2))

;; ---------------------------------------------------------------------------
;; 优化: 删不可达块
;; ---------------------------------------------------------------------------

;; jal x0 之后、且没人跳过去的块 -> 删(含它的 label)
(check-equal? (optimize-program
               '((label start) (add t0 t1 t2) (jal x0 done)
                 (label dead) (add t3 t4 t5)
                 (label done) (add t0 t0 t0)))
              '(quote ((label start) (add t0 t1 t2) (label done) (add t0 t0 t0))))

;; 有间接跳转时, 所有有名字的块都当可能的落点 -> 保留
(check-equal? (optimize-program
               '((label a) (jalr x0 ra 0) (jal x0 a) (label b) (add t0 t0 t0)))
              '(quote ((label a) (jalr x0 ra 0) (jal x0 a) (label b) (add t0 t0 t0))))

;; 同样的形状, 没有间接跳转 -> 无名块之后的 b 走不到, 删掉
(check-equal? (optimize-program
               '((label a) (add t0 t0 t0) (jal x0 a) (label b) (add t1 t1 t1)))
              '(quote ((label a) (add t0 t0 t0) (jal x0 a))))

;; 调用会回来, jal ra 之后的代码保留
(check-equal? (optimize-program
               '((label a) (jal ra f) (add t0 t0 t0)))
              '(quote ((label a) (jal ra f) (add t0 t0 t0))))

;; ebreak 之后到不了
(check-equal? (optimize-program '((label a) (ebreak) (add t0 t0 t0)))
              '(quote ((label a) (ebreak))))

;; ecall 之后可能回来, 保留
(check-equal? (optimize-program '((label a) (ecall) (add t0 t0 t0)))
              '(quote ((label a) (ecall) (add t0 t0 t0))))

;; 回边不会误删循环体
(check-equal? (optimize-program
               '((label top) (addi t0 t0 1) (blt t0 t1 top)
                 (label end) (add t1 t1 t1)))
              '(quote ((label top) (addi t0 t0 1) (blt t0 t1 top)
                       (label end) (add t1 t1 t1))))

;; ---------------------------------------------------------------------------
;; 优化: 转移到紧邻下一块
;; ---------------------------------------------------------------------------

;; jal x0 到下一块的 label -> 删跳转
(check-equal? (optimize-program '((label a) (add t0 t0 t0) (jal x0 b) (label b) (add t1 t1 t1)))
              '(quote ((label a) (add t0 t0 t0) (label b) (add t1 t1 t1))))

;; 分支到下一块的 label -> 两种走向一样, 删分支
(check-equal? (optimize-program '((label a) (beq t0 t1 b) (label b) (add t0 t0 t0)))
              '(quote ((label a) (label b) (add t0 t0 t0))))

;; 目标不是紧邻下一块 -> 不动
(check-equal? (optimize-program
               '((label a) (beq t0 t1 c) (add t0 t0 t0) (label c) (add t1 t1 t1)))
              '(quote ((label a) (beq t0 t1 c) (add t0 t0 t0) (label c) (add t1 t1 t1))))

;; 调用 (jal ra) 即使目标是下一块也不能删: 它还承担"把返回地址写进 ra"
(check-equal? (optimize-program '((label a) (jal ra b) (label b) (add t0 t0 t0)))
              '(quote ((label a) (jal ra b) (label b) (add t0 t0 t0))))

;; ---------------------------------------------------------------------------
;; 屏障: 不跨过它搬代码
;; ---------------------------------------------------------------------------

;; 跳过数据段的跳转必须保留, 数据原样
(check-equal? (optimize-program
               '((label a) (jal x0 b) (section .rodata) (bytes 1 2 3)
                 (label b) (add t0 t0 t0)))
              '(quote ((label a) (jal x0 b) (section .rodata) (bytes 1 2 3)
                       (label b) (add t0 t0 t0))))

;; 跨段被引用的 label 是根: 即使本段开头走不到, 也不删
(check-equal? (optimize-program
               '((label f) (jal x0 z)
                 (label y) (add t0 t0 t0)        ; 没人引用 -> 删
                 (section .text)
                 (label z) (add t1 t1 t1)))
              '(quote ((label f) (jal x0 z)
                       (section .text)
                       (label z) (add t1 t1 t1))))

;; ---------------------------------------------------------------------------
;; 形状 / 幂等 / 透传
;; ---------------------------------------------------------------------------

;; 进 quote-list, 出也一定是 quote-list
(check-true (and (pair? (optimize-program '((label a) (add t0 t1 t2))))
                 (eq? (car (optimize-program '((label a) (add t0 t1 t2)))) 'quote)))
(check-equal? (optimize-program '(quote ((label a) (add t0 t1 t2))))
              '(quote ((label a) (add t0 t1 t2))))

;; 幂等
(define once (optimize-program '((label a) (jal x0 c) (label b) (add t0 t0 t0)
                                 (label c) (add t1 t1 t1))))
(check-equal? (optimize-program once) once)

;; 不认识的指令原样保留, 不影响分析
(check-equal? (optimize-program '((label a) (frobnicate t0) (add t0 t0 t0)))
              '(quote ((label a) (frobnicate t0) (add t0 t0 t0))))

;; ---------------------------------------------------------------------------
;; 程序容器: (begin ...) 是壳, 不是指令
;; ---------------------------------------------------------------------------

(define-values (body has-begin?) (program-parts '(quote (begin (label a) (add t0 t0 t0)))))
(check-equal? body '((label a) (add t0 t0 t0)))
(check-true has-begin?)

;; 带 begin 进 -> 带 begin 出
(check-equal? (optimize-program '(quote (begin (label a) (jal x0 b) (label b))))
              '(quote (begin (label a) (label b))))

;; begin 不当指令: 一块, 只有 1 条指令
(define-values (begin-items _) (program-parts '(begin (label a) (add t0 t0 t0))))
(define g-begin (build-cfg begin-items))
(check-equal? (cfg-block-count g-begin) 1)
(check-equal? (block-insns (vector-ref (graph-blocks g-begin) 0)) '((add t0 t0 t0)))

;; 不带 begin 的裸列表: 出去也不带
(check-equal? (optimize-program '((label a) (add t0 t0 t0)))
              '(quote ((label a) (add t0 t0 t0))))

;; pass 名字反映功能
(check-equal? (pass-names) '(drop-unreachable drop-transfers-to-next-block))

(displayln "L2 tests: ok")
