#lang racket
;;; analyze-test.rkt -- 指令分类 + 块 / 流 / root

(require rackunit
         "helpers.rkt"
         (only-in "../riscv-compiler-rebuild/analyze/insn.rkt"
                  label-form? label-path
                  branch-instruction? jump-instruction? indirect-instruction?
                  trap-instruction? ends-block? falls-through?
                  unconditional-jump? jump-target jump-register
                  zero-register?)
         (only-in "../riscv-compiler-rebuild/analyze/analyze.rkt"
                  analyze program->sexp sexp->program
                  program-blocks program-flows
                  block-head block-items flow-succ flow-fallthrough flow-root?)
         (only-in "../riscv-compiler-rebuild/analyze/cfg.rkt"
                  build-cfg cfg-reachable referenced-labels
                  address-taken-paths graph? graph-blocks basic-block-successors))

(define (flow-at prog i) (list-ref (program-flows prog) i))
(define (block-at prog i) (list-ref (program-blocks prog) i))
(define (succ-of prog i) (flow-succ (flow-at prog i)))
(define (ft-of prog i) (flow-fallthrough (flow-at prog i)))
(define (root-of? prog i) (flow-root? (flow-at prog i)))

;; ---------------------------------------------------------------------------
;; 分类
;; ---------------------------------------------------------------------------

(for ([it (in-list '((beq a b L) (bne a b L) (c.beqz a L) (c.bnez a L)
                     (branch-far beq a b L)
                     (branch-indirect s beq a b L)))])
  (check-true (branch-instruction? it) (format "branch ~s" it)))

(for ([it (in-list '((jal x0 L) (jal ra L) (c.j L) (c.jal L) (jump-far ra L)))])
  (check-true (jump-instruction? it) (format "jump ~s" it)))

(for ([it (in-list '((jalr x0 ra 0) (c.jr a0) (c.jalr a0)))])
  (check-true (indirect-instruction? it) (format "indirect ~s" it)))

(for ([it (in-list '((ecall) (ebreak) (c.ebreak)))])
  (check-true (trap-instruction? it) (format "trap ~s" it)))

(check-false (branch-instruction? '(add a b c)))
(check-false (jump-instruction? '(add a b c)))
(check-false (indirect-instruction? '(add a b c)))
(check-false (trap-instruction? '(add a b c)))

;; falls-through? / ends-block?
(check-true  (falls-through? '(beq a b L)))
(check-true  (falls-through? '(jal ra L)))
(check-true  (falls-through? '(jal L)))                 ; 省略 rd 按 ra
(check-false (falls-through? '(jal x0 L)))
(check-true  (falls-through? '(c.jal L)))
(check-false (falls-through? '(c.j L)))
(check-true  (falls-through? '(jalr ra ra 0)))
(check-false (falls-through? '(jalr x0 ra 0)))
(check-false (falls-through? '(c.jr a0)))
(check-true  (falls-through? '(c.jalr a0)))
(check-true  (falls-through? '(ecall)))
(check-false (falls-through? '(ebreak)))
(check-false (falls-through? '(c.ebreak)))
(check-true  (falls-through? '(add a b c)))

(for ([it (in-list '((beq a b L) (jal x0 L) (jalr x0 ra 0) (ecall)))])
  (check-true (ends-block? it) (format "ends-block ~s" it)))
(check-false (ends-block? '(add a b c)))

;; 无条件跳转 / 链接寄存器
(check-true  (unconditional-jump? '(jal x0 L)))
(check-true  (unconditional-jump? '(jal zero L)))
(check-false (unconditional-jump? '(jal ra L)))
(check-true  (unconditional-jump? '(c.j L)))
(check-false (unconditional-jump? '(c.jal L)))
(check-true  (unconditional-jump? '(jump-far x0 L)))
(check-false (unconditional-jump? '(jump-far ra L)))

(check-equal? (jump-target '(beq a b (L))) '(L))
(check-equal? (jump-target '(jal x0 (lib f))) '(lib f))
(check-equal? (jump-target '(c.j L)) 'L)

(check-equal? (jump-register '(jal L)) 'ra)
(check-equal? (jump-register '(jal x0 L)) 'x0)
(check-equal? (jump-register '(jalr a0 a1 0)) 'a0)
(check-equal? (jump-register '(jump-far x0 L)) 'x0)
(check-equal? (jump-register '(c.j L)) 'x0)
(check-equal? (jump-register '(c.jal L)) 'ra)
(check-equal? (jump-register '(c.jr a0)) 'x0)
(check-equal? (jump-register '(c.jalr a0)) 'ra)

(check-true  (zero-register? 'x0))
(check-true  (zero-register? 'zero))
(check-true  (zero-register? 0))
(check-false (zero-register? 'ra))

;; label
(check-true  (label-form? '(label a f)))
(check-false (label-form? '(label)))
(check-equal? (label-path '(label a f)) '(a f))

;; ---------------------------------------------------------------------------
;; 切块: 目标 label 是 leader, 非目标 label 留在块里
;; ---------------------------------------------------------------------------

(define p-blocks
  (analyze '((label main)
             (addi a0 a0 1)
             (label mark)                 ; 非目标: 位置标记
             (addi a1 a1 1)
             (beq a0 a1 (done))
             (addi a2 a2 1)               ; 无 label 的块
             (label done)
             (jalr x0 ra 0))))

(check-equal? (length (program-blocks p-blocks)) 3)
(check-equal? (block-head (block-at p-blocks 0)) '((main)))
(check-equal? (block-items (block-at p-blocks 0))
              '((addi a0 a0 1) (label mark) (addi a1 a1 1) (beq a0 a1 (done))))
(check-equal? (block-head (block-at p-blocks 1)) '())
(check-equal? (block-items (block-at p-blocks 1)) '((addi a2 a2 1)))
(check-equal? (block-head (block-at p-blocks 2)) '((done)))
(check-equal? (block-items (block-at p-blocks 2)) '((jalr x0 ra 0)))

(check-equal? (succ-of p-blocks 0) '(2 1))
(check-equal? (ft-of p-blocks 0) 1)
(check-equal? (succ-of p-blocks 2) '())
(check-equal? (ft-of p-blocks 2) #f)

;; 连续多条 label 同属块头; 同位置多名
(define p-head
  (analyze '((label a) (label b) (addi a0 a0 1))))
(check-equal? (block-head (block-at p-head 0)) '((a) (b)))

;; 裸原子目标 = 单节链
(define p-bare (analyze '((label g) (jal x0 g))))
(check-equal? (succ-of p-bare 0) '(0))

;; ---------------------------------------------------------------------------
;; succ / fallthrough: 每种离开方式
;; ---------------------------------------------------------------------------

(define (flow-of items) (program-flows (analyze items)))

(define f-branch
  (flow-of '((label main) (beq a b (t))
             (addi a0 a0 1) (label t) (jalr x0 ra 0))))
(check-equal? (flow-succ (car f-branch)) '(2 1))
(check-equal? (flow-fallthrough (car f-branch)) 1)

(define f-jal-x0
  (flow-of '((label main) (jal x0 (t)) (label t) (jalr x0 ra 0))))
(check-equal? (flow-succ (car f-jal-x0)) '(1))
(check-equal? (flow-fallthrough (car f-jal-x0)) #f)

(define f-jal-ra
  (flow-of '((label main) (jal ra (t)) (label t) (jalr x0 ra 0))))
(check-equal? (flow-succ (car f-jal-ra)) '(1))
(check-equal? (flow-fallthrough (car f-jal-ra)) 1)

(define f-jalr-x0
  (flow-of '((label main) (jalr x0 ra 0) (label t) (jalr x0 ra 0))))
(check-equal? (flow-succ (car f-jalr-x0)) '())
(check-equal? (flow-fallthrough (car f-jalr-x0)) #f)

(define f-jalr-ra
  (flow-of '((label main) (jalr ra ra 0) (label t) (jalr x0 ra 0))))
(check-equal? (flow-succ (car f-jalr-ra)) '(1))
(check-equal? (flow-fallthrough (car f-jalr-ra)) 1)

(define f-ecall
  (flow-of '((label main) (ecall) (label t) (jalr x0 ra 0))))
(check-equal? (flow-succ (car f-ecall)) '(1))
(check-equal? (flow-fallthrough (car f-ecall)) 1)

(define f-ebreak
  (flow-of '((label main) (ebreak) (label t) (jalr x0 ra 0))))
(check-equal? (flow-succ (car f-ebreak)) '())
(check-equal? (flow-fallthrough (car f-ebreak)) #f)

;; 目标不存在: 不加边
(define f-missing
  (flow-of '((label main) (beq a b (nope)) (jalr x0 ra 0))))
(check-equal? (flow-succ (car f-missing)) '(1))
(check-equal? (flow-fallthrough (car f-missing)) 1)

;; 远形式按 link 判断
(define f-jump-far-x0
  (flow-of '((label main) (jump-far x0 (t)) (label t) (jalr x0 ra 0))))
(check-equal? (flow-succ (car f-jump-far-x0)) '(1))
(check-equal? (flow-fallthrough (car f-jump-far-x0)) #f)

(define f-jump-far-ra
  (flow-of '((label main) (jump-far ra (t)) (label t) (jalr x0 ra 0))))
(check-equal? (flow-succ (car f-jump-far-ra)) '(1))
(check-equal? (flow-fallthrough (car f-jump-far-ra)) 1)

;; ---------------------------------------------------------------------------
;; root?: 入口 + (有间接跳转时)地址被取过的块
;; ---------------------------------------------------------------------------

(define indirect-items
  '((label main) (la t0 (fn)) (jalr x0 t0 0)
    (label fn) (addi a0 a0 1) (jalr x0 ra 0)))
(define p-indirect (analyze indirect-items))

(check-true  (root-of? p-indirect 0))
(check-true  (root-of? p-indirect 1))       ; la 取过 fn 的地址

;; 没有间接跳转: 数据/取地址都不会凭空造 root
(define no-indirect-items
  '((label main) (la t0 (fn)) (jal x0 (fn))
    (label fn) (addi a0 a0 1) (ebreak)))
(define p-no-indirect (analyze no-indirect-items))
(check-false (root-of? p-no-indirect 1))

;; 数据里的地址字: 只有有间接跳转时才算 root
(define jalr-only '((label main) (jalr x0 t0 0)
                    (label fn) (addi a0 a0 1) (jalr x0 ra 0)))
(check-false (root-of? (analyze jalr-only) 1))
(check-true  (root-of? (analyze jalr-only '((label d tbl) (value 8 (fn)))) 1))

;; 地址表达式里的每条链都算
(check-true
 (root-of? (analyze jalr-only '((label d t) (value 4 (- (fn) (main))))) 1))
(check-true
 (root-of? (analyze jalr-only '((label d t) (value 4 (+ (- (fn) (main)) 8)))) 1))

;; 数据 item 不进块 / 不进 CFG
(check-equal? (length (program-blocks (analyze jalr-only '((label d tbl) (value 8 (fn))))))
              2)

;; 内部分支引用不是 root
(define branch-only
  '((label main) (beq a b (done)) (label done) (jalr x0 ra 0)))
(check-false (root-of? (analyze branch-only) 1))

;; ---------------------------------------------------------------------------
;; cfg 小 API
;; ---------------------------------------------------------------------------

(define items
  '((label a) (beq t0 t1 (c))
    (label b) (addi t0 t0 1) (jalr x0 ra 0)
    (label c) (addi t1 t1 1) (jalr x0 ra 0)))
(check-equal? (referenced-labels items) '((c)))
(check-equal? (address-taken-paths '((la t0 (a)))) '((a)))
(check-equal? (address-taken-paths '((value 8 (- (b) (c)))))
              '((b) (c)))

(define g (build-cfg items))
(check-true (graph? g))
(check-equal? (cfg-reachable g '(0)) '(0 1 2))
(check-equal? (cfg-reachable g '(1)) '(1))

;; ---------------------------------------------------------------------------
;; program <-> sexp
;; ---------------------------------------------------------------------------

(define p (analyze '((label main) (beq a b (done))
                     (label done) (jalr x0 ra 0))))
(define fields (program->sexp p))
(check-equal? fields
              '((blocks (block ((main)) (beq a b (done)))
                        (block ((done)) (jalr x0 ra 0)))
                (flows (flow (succ 1) (fallthrough 1) (root? #t))
                       (flow (succ) (fallthrough #f) (root? #f)))))
(check-equal? (program->sexp (sexp->program fields)) fields)
(check-error "blocks/flows 不等长"
             (lambda ()
               (sexp->program '((blocks (block () (add a b c)))
                                (flows (flow (succ) (fallthrough #f) (root? #t))
                                       (flow (succ) (fallthrough #f) (root? #f)))))))
(check-error "缺字段"
             (lambda () (sexp->program '((blocks)))))

(finish-tests "analyze")
