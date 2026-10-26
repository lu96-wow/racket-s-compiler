#lang racket
;;; L4/test.rkt -- 死代码消除(会改控制流): block list -> block list

(require rackunit
         "dce.rkt"
         (only-in "../L3/analyze.rkt" analyze blocks->sexp sexp->blocks
                  block-id block-labels block-insns block-succ block-fallthrough block-root?))

;; ---- 测试用视图 ------------------------------------------------------------

;; 块列表 -> 扁平 item(语义测试只看内容)
(define (flat blocks)
  (append* (for/list ([b (in-list blocks)])
             (append (for/list ([l (in-list (block-labels b))]) (cons 'label l))
                     (block-insns b)))))

;; 程序 -> 分析 -> 消除 -> 扁平视图
(define (dce items) (flat (eliminate-dead (analyze items))))

(define (by-id blocks n) (findf (lambda (b) (= n (block-id b))) blocks))

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

;; 有间接跳转 + b 被分支直接引用 -> 保留
(check-equal? (dce '((label a) (jalr x0 ra 0) (beq t0 t1 (b))
                     (label c) (add t0 t0 t0)
                     (label b) (add t1 t1 t1)))
              '((label a) (jalr x0 ra 0) (label b) (add t1 t1 t1)))

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
(check-equal? (map block-id blocks-after) '(0 1))
(check-equal? (block-labels (by-id blocks-after 1)) '((c)))
(check-equal? (block-succ (by-id blocks-after 0)) '(1))
(check-equal? (block-fallthrough (by-id blocks-after 0)) 1)

;; root? 由分析算出, 消除后原样保留
(check-true (block-root? (by-id blocks-after 0)))
(check-true (block-root? (by-id blocks-after 1)))

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
(check-equal? (block-insns (by-id blocks-simple 0)) '((add t0 t0 t0)))
(check-equal? (block-succ (by-id blocks-simple 0)) '(1))
(check-equal? (block-fallthrough (by-id blocks-simple 0)) 1)

;; ---------------------------------------------------------------------------
;; 形状 / 幂等 / pass 名
;; ---------------------------------------------------------------------------

;; 输入输出都是块列表, 不是 s-exp
(check-true (list? (eliminate-dead (analyze '((label a) (add t0 t1 t2))))))
(check-equal? (blocks->sexp (eliminate-dead (analyze '((label a) (add t0 t1 t2)))))
              '((block (id 0) (labels (a)) (insns (add t0 t1 t2))
                       (succ) (fallthrough #f) (root? #t))))

;; 幂等
(define once (eliminate-dead (analyze '((label a) (jal x0 c) (label b) (add t0 t0 t0)
                                       (label c) (add t1 t1 t1)))))
(check-equal? (eliminate-dead once) once)

;; 不认识的指令原样保留
(check-equal? (dce '((label a) (frobnicate t0) (add t0 t0 t0)))
              '((label a) (frobnicate t0) (add t0 t0 t0)))

;; pass 名字反映功能
(check-equal? (pass-names) '(drop-unreachable drop-transfers-to-next-block))

;; 直接喂 s-exp 块(上一版的产物)也能读: sexp->blocks 是 IR 的读入口
(check-equal? (flat (eliminate-dead (sexp->blocks
                                     '((block (id 0) (labels (a)) (insns (add t0 t0 t0))
                                              (succ) (fallthrough #f) (root? #t))))))
              '((label a) (add t0 t0 t0)))

(displayln "L4 tests: ok")
