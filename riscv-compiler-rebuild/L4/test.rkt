#lang racket
;;; L4/test.rkt -- 死代码消除(会改控制流): block list -> block list

(require rackunit
         "dce.rkt"
         (only-in "../L3/analyze.rkt" analyze program? program-blocks program-flows
                  block-head block-items flow-succ flow-fallthrough flow-root?
                  program->sexp sexp->program))

;; ---- 测试用视图 ------------------------------------------------------------

;; 程序 -> 扁平 item(语义测试只看内容)
(define (flat prog)
  (append* (for/list ([b (in-list (program-blocks prog))])
             (append (for/list ([l (in-list (block-head b))]) (cons 'label l))
                     (block-items b)))))

;; 程序 -> 分析 -> 消除 -> 扁平视图
(define (dce items) (flat (eliminate-dead (analyze items))))

(define (block-at prog n) (list-ref (program-blocks prog) n))
(define (flow-at prog n) (list-ref (program-flows prog) n))

;; ---------------------------------------------------------------------------
;; 删不可达块
;; ---------------------------------------------------------------------------

;; jal x0 之后、且没人跳过去的块 -> 删(含它的 label)
(check-equal? (dce '((label start) (add t0 t1 t2) (jal x0 done)
                     (label dead) (add t3 t4 t5)
                     (label done) (add t0 t0 t0)))
              '((label start) (add t0 t1 t2) (label done) (add t0 t0 t0)))

;; 有间接跳转, 但 b 既没被直接引用、地址也没被取过 -> 仍然不可达
(check-equal? (dce '((label a) (jalr x0 ra 0) (jal x0 a) (label b) (add t0 t0 t0)))
              '((label a) (jalr x0 ra 0)))

;; 有间接跳转 + b 的地址被取过(la) -> 保留
(check-equal? (dce '((label a) (la t0 (b)) (jalr x0 ra 0) (jal x0 a)
                     (label b) (add t0 t0 t0)))
              '((label a) (la t0 (b)) (jalr x0 ra 0) (label b) (add t0 t0 t0)))

;; 引用来自死代码 -> 目标照样删(ret 之后那块走不到)
(check-equal? (dce '((label a) (jalr x0 ra 0) (beq t0 t1 (b))
                     (label c) (add t0 t0 t0)
                     (label b) (add t1 t1 t1)))
              '((label a) (jalr x0 ra 0)))

;; 没有间接跳转: 无名块之后的 b 走不到
(check-equal? (dce '((label a) (add t0 t0 t0) (jal x0 a) (label b) (add t1 t1 t1)))
              '((label a) (add t0 t0 t0) (jal x0 a)))

;; 调用会回来, jal ra 之后的代码保留
(check-equal? (dce '((label a) (jal ra f) (add t0 t0 t0)))
              '((label a) (jal ra f) (add t0 t0 t0)))

;; ebreak 之后到不了
(check-equal? (dce '((label a) (ebreak) (add t0 t0 t0)))
              '((label a) (ebreak)))

;; ecall 之后可能回来, 保留
(check-equal? (dce '((label a) (ecall) (add t0 t0 t0)))
              '((label a) (ecall) (add t0 t0 t0)))

;; 回边不会误删循环体
(check-equal? (dce '((label top) (addi t0 t0 1) (blt t0 t1 top)
                     (label end) (add t1 t1 t1)))
              '((label top) (addi t0 t0 1) (blt t0 t1 top)
                (label end) (add t1 t1 t1)))

;; 删块之后重新编号: id 连续, succ/fallthrough 指向新 id
(define blocks-after
  (eliminate-dead (analyze '((label a) (add t0 t0 t0) (jal x0 (c))
                            (label dead) (add t1 t1 t1)
                            (label c) (add t2 t2 t2)))))
(check-equal? (range (length (program-blocks blocks-after))) '(0 1))
(check-equal? (block-head (block-at blocks-after 1)) '((c)))
(check-equal? (flow-succ (flow-at blocks-after 0)) '(1))
(check-equal? (flow-fallthrough (flow-at blocks-after 0)) 1)

;; root? 由分析算出, 消除后原样保留(只有入口是根, 内部边不算)
(check-true (flow-root? (flow-at blocks-after 0)))
(check-false (flow-root? (flow-at blocks-after 1)))

;; ---------------------------------------------------------------------------
;; 删「跳到紧邻下一块」的转移
;; ---------------------------------------------------------------------------

;; jal x0 到下一块的 label -> 删跳转
(check-equal? (dce '((label a) (add t0 t0 t0) (jal x0 b) (label b) (add t1 t1 t1)))
              '((label a) (add t0 t0 t0) (label b) (add t1 t1 t1)))

;; 分支到下一块的 label -> 两种走向一样, 删分支
(check-equal? (dce '((label a) (beq t0 t1 b) (label b) (add t0 t0 t0)))
              '((label a) (label b) (add t0 t0 t0)))

;; 目标不是紧邻下一块 -> 不动
(check-equal? (dce '((label a) (beq t0 t1 c) (add t0 t0 t0) (label c) (add t1 t1 t1)))
              '((label a) (beq t0 t1 c) (add t0 t0 t0) (label c) (add t1 t1 t1)))

;; 调用 (jal ra) 即使目标是下一块也不能删: 它还承担"把返回地址写进 ra"
(check-equal? (dce '((label a) (jal ra b) (label b) (add t0 t0 t0)))
              '((label a) (jal ra b) (label b) (add t0 t0 t0)))

;; 删转移后 succ/fallthrough 变成顺序边
(define blocks-simple
  (eliminate-dead (analyze '((label a) (add t0 t0 t0) (jal x0 b) (label b) (add t1 t1 t1)))))
(check-equal? (block-items (block-at blocks-simple 0)) '((add t0 t0 t0)))
(check-equal? (flow-succ (flow-at blocks-simple 0)) '(1))
(check-equal? (flow-fallthrough (flow-at blocks-simple 0)) 1)

;; ---------------------------------------------------------------------------
;; 空块并进下一块
;; ---------------------------------------------------------------------------

;; 空块的 label 与下一块同址, 所以并过去(地址不变)
(check-equal? (dce '((label a) (jal x0 (b)) (label b) (add t0 t0 t0)))
              '((label a) (label b) (add t0 t0 t0)))

;; 并完只剩一块, labels 是 (a) (b), root? 保留
(define blocks-merged
  (eliminate-dead (analyze '((label a) (jal x0 (b)) (label b) (add t0 t0 t0)))))
(check-equal? (range (length (program-blocks blocks-merged))) '(0))
(check-equal? (block-head (block-at blocks-merged 0)) '((a) (b)))
(check-equal? (block-items (block-at blocks-merged 0)) '((add t0 t0 t0)))
(check-true (flow-root? (flow-at blocks-merged 0)))

;; 空块本身是根(地址被取过 + 有 jalr) -> 并过去后根跟着走
(define blocks-merged-root
  (eliminate-dead (analyze '((label a) (la t0 (b)) (jalr x0 t0 0)
                             (label x) (jal x0 (x))     ; 占位: 让 a 的下一块不是 b
                             (label b) (jal x0 (c))     ; b 会变成空块
                             (label c) (add t0 t0 t0)))))
(check-equal? (range (length (program-blocks blocks-merged-root))) '(0 1))
(check-equal? (block-head (block-at blocks-merged-root 1)) '((b) (c)))
(check-true (flow-root? (flow-at blocks-merged-root 1)))
;; jalr x0 没有顺序边, 所以入口块的后继是空的
(check-equal? (flow-succ (flow-at blocks-merged-root 0)) '())

;; 前驱指向空块的边不能丢: 空块并进下一块后, 这条边要改指并后的块
(define prog-edge (analyze '((label a) (beq t0 t1 (b)) (jal x0 (c))
                             (label b) (jal x0 (c))
                             (label c) (add t0 t0 t0))))
(define after-transfers
  ((cdr (assoc 'drop-transfers-to-next-block passes)) prog-edge))
(define after-merge
  ((cdr (assoc 'merge-empty-blocks passes)) after-transfers))
(check-equal? (map block-head (program-blocks after-merge)) '(((a)) () ((b) (c))))
(check-equal? (flow-succ (flow-at after-merge 0)) '(2 1))   ; 分支: 目标 + 顺序
(check-equal? (flow-succ (flow-at after-merge 1)) '(2))     ; 跳向 (c) 的边改指并后的块

;; 末尾的空块没有下一块 -> 原样保留(它可能是代码末尾的 label)
;; 用 jal ra 让 (z) 被引用(否则它会被当成死代码删掉)
(check-equal? (dce '((label a) (jal ra (z)) (label z)))
              '((label a) (jal ra (z)) (label z)))
(define blocks-tail (eliminate-dead (analyze '((label a) (jal ra (z)) (label z)))))
(check-equal? (map block-head (program-blocks blocks-tail)) '(((a)) ((z))))
(check-equal? (map block-items (program-blocks blocks-tail)) '(((jal ra (z))) ()))

;; 连续多个空块一起并
(check-equal? (dce '((label a) (jal x0 (b))
                     (label b) (jal x0 (c))
                     (label c) (add t0 t0 t0)))
              '((label a) (label b) (label c) (add t0 t0 t0)))

;; 分支/跳转目标是紧邻下一块时, 删掉后前一块也变成空块 -> 继续并
(check-equal? (dce '((label a) (beq t0 t1 (b))
                     (label b) (jal x0 (c))
                     (label c) (add t0 t0 t0)))
              '((label a) (label b) (label c) (add t0 t0 t0)))

;; ---------------------------------------------------------------------------
;; 形状 / 幂等 / pass 名
;; ---------------------------------------------------------------------------

;; 输入输出都是块列表, 不是 s-exp
(check-true (program? (eliminate-dead (analyze '((label a) (add t0 t1 t2))))))
(check-equal? (program->sexp (eliminate-dead (analyze '((label a) (add t0 t1 t2)))))
              (program->sexp (analyze '((label a) (add t0 t1 t2)))))

;; 幂等
(define once (eliminate-dead (analyze '((label a) (jal x0 c) (label b) (add t0 t0 t0)
                                       (label c) (add t1 t1 t1)))))
(check-equal? (eliminate-dead once) once)

;; 不认识的指令原样保留
(check-equal? (dce '((label a) (frobnicate t0) (add t0 t0 t0)))
              '((label a) (frobnicate t0) (add t0 t0 t0)))

;; pass 名字反映功能
(check-equal? (pass-names) '(drop-unreachable drop-transfers-to-next-block merge-empty-blocks))

;; program <-> sexp 往返(测试/demo 写字面量用)
(define prog-literal
  (sexp->program
   '(program
     (blocks (block ((a)) (add t0 t0 t0)))
     (flows (flow (succ) (fallthrough #f) (root? #t))))))
(check-equal? (flat (eliminate-dead prog-literal)) '((label a) (add t0 t0 t0)))
(check-equal? (sexp->program (program->sexp prog-literal)) prog-literal)

(displayln "L4 tests: ok")
