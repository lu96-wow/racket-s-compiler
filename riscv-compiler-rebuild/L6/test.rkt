#lang racket
;;; L6/test.rkt -- 分支松弛

(require rackunit
         "relax.rkt"
         (only-in "../L3/analyze.rkt" sexp->program)
         (only-in "../L5/layout.rkt" layout-problems))

;; ---------------------------------------------------------------------------
;; 小工具
;; ---------------------------------------------------------------------------

(define (segments-of layout) (cdr (assoc 'segments layout)))
(define (seg-of layout name)
  (findf (lambda (s) (equal? (cadr (assoc 'name (cdr s))) name)) (segments-of layout)))
(define (items-of layout name) (cdr (assoc 'items (cdr (seg-of layout name)))))
(define (problems-of layout) (layout-problems layout))

;; 一条条件分支 + 一个 fallthrough 块 + 远段里的冷块
(define (make-prog br)
  (sexp->program
   `((blocks
      (block ((p main)) ,br)
      (block () (addi a0 a0 1) (jalr x0 ra 0))
      (block ((q cold)) (addi a1 a1 1) (jalr x0 ra 0)))
     (flows
      (flow (succ 2 1) (fallthrough 1) (root? #t))
      (flow (succ) (fallthrough #f) (root? #f))
      (flow (succ) (fallthrough #f) (root? #f))))))

;; cold 放在 cold-start, 决定距离
(define (run br cold-start)
  (relax (make-prog br) '()
         `((segments (segment p code #x1000 #x1014 4)   ; 20B: 够放 branch-indirect + 一个块
                     (segment q code ,cold-start #x10000000 4))
           (place p (p main))
           (place q (q cold)))))

;; ---------------------------------------------------------------------------
;; 提升表: 语义不变, 尺寸只增
;; ---------------------------------------------------------------------------

(check-equal? (far-step '(beq a b (l)))   '(branch-far beq a b (l)))
(check-equal? (far-step '(bgeu a b (l)))  '(branch-far bgeu a b (l)))
(check-equal? (far-step '(branch-far beq a b (l))) '(branch-indirect beq a b (l)))
;; 压缩 -> 普通(先升一档, 还远就下一轮)
(check-equal? (far-step '(c.beqz a (l))) '(beq a x0 (l)))
(check-equal? (far-step '(c.bnez a (l))) '(bne a x0 (l)))
(check-equal? (far-step '(c.j (l)))      '(jal x0 (l)))
(check-equal? (far-step '(c.jal (l)))    '(jal ra (l)))
;; 跳转: link 保持不变, 省略 rd 就是 ra
(check-equal? (far-step '(jal ra (l))) '(jump-far ra (l)))
(check-equal? (far-step '(jal x0 (l))) '(jump-far x0 (l)))
(check-equal? (far-step '(jal (l)))    '(jump-far ra (l)))
;; 到头了
(check-false (far-step '(jump-far ra (l))))
(check-false (far-step '(branch-indirect beq a b (l))))
(check-false (far-step '(addi a0 a0 1)))

;; ---------------------------------------------------------------------------
;; 一轮: b* 超范围 -> branch-far
;; ---------------------------------------------------------------------------

(define r1 (run '(beq t0 t1 (q cold)) #x2000))
;; 分支在 0, 目标在 0x2000: d = 4096, 超出 [-4096, 4094]
(check-equal? (items-of r1 'p)
              '((offset 0 (label p main))
                (offset 0 (branch-far beq t0 t1 (q cold)))
                (offset 8 (addi a0 a0 1))
                (offset 12 (jalr x0 ra 0))))
(check-equal? (problems-of r1) '())

;; 不够远就什么都不动
(define r0 (run '(beq t0 t1 (q cold)) #x1020))
(check-equal? (items-of r0 'p)
              '((offset 0 (label p main))
                (offset 0 (beq t0 t1 (q cold)))
                (offset 4 (addi a0 a0 1))
                (offset 8 (jalr x0 ra 0))))
(check-equal? (problems-of r0) '())

;; 边界: 4 字节对齐下 +4092 还能编码, +4096 就不行(区间不是幅度的理由)
(check-equal? (problems-of (run '(beq t0 t1 (q cold)) #x1FFC)) '())
(check-equal? (items-of (run '(beq t0 t1 (q cold)) #x1FFC) 'p)
              '((offset 0 (label p main))
                (offset 0 (beq t0 t1 (q cold)))
                (offset 4 (addi a0 a0 1))
                (offset 8 (jalr x0 ra 0))))

;; ---------------------------------------------------------------------------
;; 两轮: 压缩分支先变普通, 再变远形式
;; ---------------------------------------------------------------------------

(define r2 (run '(c.beqz t0 (q cold)) #x2000))
(check-equal? (items-of r2 'p)
              '((offset 0 (label p main))
                (offset 0 (branch-far beq t0 x0 (q cold)))
                (offset 8 (addi a0 a0 1))
                (offset 12 (jalr x0 ra 0))))
(check-equal? (problems-of r2) '())

;; ---------------------------------------------------------------------------
;; 三级: >±1MB 需要 scratch
;; ---------------------------------------------------------------------------

;; >±1MB: 升到 branch-indirect 就停 —— 空槽不归本层填, 原样留给
;; "动态内存布局 / 寄存器使用"那一层(未实现)。scratch-hole 就是交接点。
(define r3 (run '(beq t0 t1 (q cold)) #x200000))
(check-equal? (items-of r3 'p)
              '((offset 0 (label p main))
                (offset 0 (branch-indirect beq t0 t1 (q cold)))
                (offset 12 (addi a0 a0 1))
                (offset 16 (jalr x0 ra 0))))
(check-equal? (problems-of r3)
              '((scratch-hole p 0 (branch-indirect beq t0 t1 (q cold)) (code 0 0))))

;; ---------------------------------------------------------------------------
;; 跳转也一样: jal -> jump-far; link 是零寄存器时留空槽
;; ---------------------------------------------------------------------------

(define r5 (run '(jal x0 (q cold)) #x200000))
(check-equal? (items-of r5 'p)
              '((offset 0 (label p main))
                (offset 0 (jump-far x0 (q cold)))
                (offset 8 (addi a0 a0 1))
                (offset 12 (jalr x0 ra 0))))
(check-equal? (problems-of r5)
              '((scratch-hole p 0 (jump-far x0 (q cold)) (code 0 0))))

;; link 非零不用 scratch
(define r6 (run '(jal ra (q cold)) #x200000))
(check-equal? (items-of r6 'p)
              '((offset 0 (label p main))
                (offset 0 (jump-far ra (q cold)))
                (offset 8 (addi a0 a0 1))
                (offset 12 (jalr x0 ra 0))))
(check-equal? (problems-of r6) '())

;; ---------------------------------------------------------------------------
;; 地址随尺寸重算 / 其它段不受影响
;; ---------------------------------------------------------------------------

(define r7 (run '(beq t0 t1 (q cold)) #x2000))
(check-equal? (items-of r7 'q)
              '((offset 0 (label q cold))
                (offset 0 (addi a1 a1 1))
                (offset 4 (jalr x0 ra 0))))
(check-equal? (items-of r0 'q) (items-of r7 'q))

;; ---------------------------------------------------------------------------
;; 不收敛就是 bug: 轮数上限要报出来
;; ---------------------------------------------------------------------------

(check-exn exn:fail?
           (lambda () (relax (make-prog '(beq t0 t1 (q cold))) '()
                             '((segments (segment p code #x1000 #x1014 4)
                                         (segment q code #x200000 #x10000000 4))
                               (place p (p main)) (place q (q cold)))
                             #:max-rounds 1)))

(displayln "L6 tests: ok")
