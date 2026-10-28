#lang racket
;;; dce-test.rkt -- 死代码消除: 可达性 / 冗余转移 / 空块合并

(require rackunit
         "helpers.rkt"
         (only-in "../riscv-compiler-rebuild/analyze/analyze.rkt"
                  analyze program->sexp program-blocks program-flows
                  make-flow block-head block-items flow-root?)
         (only-in "../riscv-compiler-rebuild/dce/dce.rkt"
                  eliminate-dead optimize-program passes pass-names))

(define (dead p) (eliminate-dead p))
(define (block-at prog i) (list-ref (program-blocks prog) i))
(define (flow-at prog i) (list-ref (program-flows prog) i))

;; ---------------------------------------------------------------------------
;; pass 表
;; ---------------------------------------------------------------------------

(check-equal? (pass-names)
              '(drop-unreachable drop-transfers-to-next-block merge-empty-blocks))
(check-equal? (map car passes) (pass-names))

;; ---------------------------------------------------------------------------
;; 删不可达块
;; ---------------------------------------------------------------------------

(define p-unreachable
  (analyze '((label main) (addi a0 a0 1) (jal x0 (end))
             (label dead) (addi a1 a1 1) (jalr x0 ra 0)
             (label end) (jalr x0 ra 0))))

(check-equal? (length (program-blocks p-unreachable)) 3)
(define out-unreachable (dead p-unreachable))
(check-equal? (program->sexp out-unreachable)
              '((blocks (block ((main)) (addi a0 a0 1))
                        (block ((end)) (jalr x0 ra 0)))
                (flows (flow (succ 1) (fallthrough 1) (root? #t))
                       (flow (succ) (fallthrough #f) (root? #f)))))

;; 从 root? 出发, 不是从入口下标出发
(define p-root
  (program-of
   '((blocks (block ((main)) (jalr x0 ra 0))
             (block ((alt)) (addi a0 a0 1) (jalr x0 ra 0)))
     (flows (flow (succ) (fallthrough #f) (root? #f))
            (flow (succ) (fallthrough #f) (root? #t))))))
(check-equal? (block-head (block-at (dead p-root) 0)) '((alt)))

;; ---------------------------------------------------------------------------
;; 转移到紧邻下一块 -> 删掉
;; ---------------------------------------------------------------------------

(define p-branch-next
  (program-of
   '((blocks (block ((main)) (addi a0 a0 1) (beq a0 a1 (next)))
             (block ((next)) (jalr x0 ra 0)))
     (flows (flow (succ 1) (fallthrough 1) (root? #t))
            (flow (succ) (fallthrough #f) (root? #f))))))
(define out-branch (dead p-branch-next))
(check-equal? (block-items (block-at out-branch 0)) '((addi a0 a0 1)))
(check-equal? (program-flows out-branch)
              (list (make-flow '(1) 1 #t)
                    (make-flow '() #f #f)))

(define p-jump-next
  (program-of
   '((blocks (block ((main)) (addi a0 a0 1) (jal x0 (next)))
             (block ((next)) (jalr x0 ra 0)))
     (flows (flow (succ 1) (fallthrough #f) (root? #t))
            (flow (succ) (fallthrough #f) (root? #f))))))
(check-equal? (block-items (block-at (dead p-jump-next) 0))
              '((addi a0 a0 1)))

;; 远形式同样适用
(define p-far-branch-next
  (program-of
   '((blocks (block ((main)) (addi a0 a0 1)
                          (branch-far beq a0 a1 (next)))
             (block ((next)) (jalr x0 ra 0)))
     (flows (flow (succ 1) (fallthrough 1) (root? #t))
            (flow (succ) (fallthrough #f) (root? #f))))))
(check-equal? (block-items (block-at (dead p-far-branch-next) 0))
              '((addi a0 a0 1)))

(define p-far-jump-next
  (program-of
   '((blocks (block ((main)) (addi a0 a0 1) (jump-far x0 (next)))
             (block ((next)) (jalr x0 ra 0)))
     (flows (flow (succ 1) (fallthrough #f) (root? #t))
            (flow (succ) (fallthrough #f) (root? #f))))))
(check-equal? (block-items (block-at (dead p-far-jump-next) 0))
              '((addi a0 a0 1)))

;; 目标不是下一块: 保留转移
(define p-not-next
  (program-of
   '((blocks (block ((main)) (beq a0 a1 (other)))
             (block () (jalr x0 ra 0))
             (block ((other)) (jalr x0 ra 0)))
     (flows (flow (succ 2 1) (fallthrough 1) (root? #t))
            (flow (succ 2) (fallthrough 2) (root? #f))
            (flow (succ) (fallthrough #f) (root? #f))))))
(check-equal? (block-items (block-at (dead p-not-next) 0))
              '((beq a0 a1 (other))))

;; ---------------------------------------------------------------------------
;; 空块并进下一块; label 地址不变
;; ---------------------------------------------------------------------------

(define p-empty
  (program-of
   '((blocks (block ((main)) (addi a0 a0 1) (jal x0 (hot)))
             (block ((hot)))                    ; 空块
             (block ((end)) (jalr x0 ra 0)))
     (flows (flow (succ 1) (fallthrough #f) (root? #t))
            (flow (succ 2) (fallthrough 2) (root? #f))
            (flow (succ) (fallthrough #f) (root? #f))))))
(define out-empty (dead p-empty))
(check-equal? (length (program-blocks out-empty)) 2)
(check-equal? (block-head (block-at out-empty 1)) '((hot) (end)))
(check-equal? (block-items (block-at out-empty 1)) '((jalr x0 ra 0)))
(check-equal? (program-flows out-empty)
              (list (make-flow '(1) 1 #t)
                    (make-flow '() #f #f)))

;; 空块的 root? 会被带到合并后的块
(define p-empty-root
  (program-of
   '((blocks (block ((main)) (jalr x0 ra 0))
             (block ((alt)))                    ; 空块, root?
             (block ((end)) (jalr x0 ra 0)))
     (flows (flow (succ) (fallthrough #f) (root? #t))
            (flow (succ 2) (fallthrough 2) (root? #t))
            (flow (succ) (fallthrough #f) (root? #f))))))
(define out-empty-root (dead p-empty-root))
(check-equal? (block-head (block-at out-empty-root 0)) '((main)))
(check-equal? (block-head (block-at out-empty-root 1)) '((alt) (end)))
(check-true (flow-root? (flow-at out-empty-root 1)))

;; 末尾空块没有下一块可并: 保留
(define p-tail-empty
  (program-of
   '((blocks (block ((main)) (jal x0 (tail)))
             (block ((tail))))
     (flows (flow (succ 1) (fallthrough #f) (root? #t))
            (flow (succ) (fallthrough #f) (root? #f))))))
(check-equal? (length (program-blocks (dead p-tail-empty))) 2)

;; 空块 + 冗余转移一起跑: 先删转移, 再合并
(define p-both
  (program-of
   '((blocks (block ((main)) (beq a0 a1 (next)))
             (block ((next)) (jalr x0 ra 0)))
     (flows (flow (succ 1) (fallthrough 1) (root? #t))
            (flow (succ) (fallthrough #f) (root? #f))))))
(define out-both (dead p-both))
(check-equal? (length (program-blocks out-both)) 1)
(check-equal? (block-head (block-at out-both 0)) '((main) (next)))
(check-equal? (block-items (block-at out-both 0)) '((jalr x0 ra 0)))

;; ---------------------------------------------------------------------------
;; 不动点 / 幂等
;; ---------------------------------------------------------------------------

(check-equal? (dead out-empty) out-empty)
(check-equal? (optimize-program out-empty) out-empty)
(check-equal? (dead p-unreachable) (dead (dead p-unreachable)))

(finish-tests "dce")
