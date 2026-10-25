#lang racket/base

;; ============================================================
;; 底层算法链测试
;; ============================================================

(require rackunit
         "../asm.rkt"
         "../cfg.rkt"
         "../branch-opt.rkt"
         "../liveness.rkt"
         "../interference.rkt"
         "../regalloc-graph.rkt"
         "../layout.rkt"
         "../compile-asm.rkt")

(define basic-asm
  '((label main)
    (addi v0 x0 0)
    (addi v1 x0 1)
    (bge v0 v1 L0)
    (addi v2 x0 42)
    (addi v3 v2 0)
    (jal x0 L1)
    (label L0)
    (addi v4 x0 7)
    (addi v3 v4 0)
    (label L1)
    (addi a0 v3 0)
    (jalr x0 ra 0)))

;; ------------------------------------------------------------
;; CFG
;; ------------------------------------------------------------

(define cfg (build-cfg basic-asm))

(check-equal? cfg
              '(cfg
                (blocks
                 ((block B0
                         (labels (main))
                         (insns ((addi v0 x0 0)
                                 (addi v1 x0 1)
                                 (bge v0 v1 L0))))
                  (block B1
                         (labels ())
                         (insns ((addi v2 x0 42)
                                 (addi v3 v2 0)
                                 (jal x0 L1))))
                  (block B2
                         (labels (L0))
                         (insns ((addi v4 x0 7)
                                 (addi v3 v4 0))))
                  (block B3
                         (labels (L1))
                         (insns ((addi a0 v3 0)
                                 (jalr x0 ra 0))))))
                (label-map ((main . B0) (L0 . B2) (L1 . B3)))
                (succ ((B0 B2 B1)
                       (B1 B3)
                       (B2 B3)
                       (B3)))))

;; ------------------------------------------------------------
;; branch-opt
;; ------------------------------------------------------------

;; 跳转到下一个 block：删除 jal。
(check-equal?
 (optimize-branches
  (build-cfg
   '((label main)
     (addi v0 x0 1)
     (jal x0 L0)
     (label L0)
     (addi a0 v0 0)
     (jalr x0 ra 0))))
 '((label main)
   (addi v0 x0 1)
   (label L0)
   (addi a0 v0 0)
   (jalr x0 ra 0)))

;; 不可达 block 删除，然后跳转变成跳到下一块，也删除。
(check-equal?
 (optimize-branches
  (build-cfg
   '((label main)
     (jal x0 L1)
     (addi v0 x0 1)
     (label L0)
     (addi v1 x0 2)
     (label L1)
     (addi a0 x0 0)
     (jalr x0 ra 0))))
 '((label main)
   (label L1)
   (addi a0 x0 0)
   (jalr x0 ra 0)))

;; ------------------------------------------------------------
;; liveness
;; ------------------------------------------------------------

(define live (compute-liveness cfg))

(check-equal? live
              '(liveness
                (B0 (use ()) (def (v0 v1)) (in (ra)) (out (ra)))
                (B1 (use ()) (def (v2 v3)) (in (ra)) (out (ra v3)))
                (B2 (use ()) (def (v3 v4)) (in (ra)) (out (ra v3)))
                (B3 (use (ra v3)) (def (a0)) (in (ra v3)) (out ()))))

;; ------------------------------------------------------------
;; interference
;; ------------------------------------------------------------

(define interference (build-interference cfg live))

(check-equal? interference
              '(interference
                (a0 ra)
                (ra a0 v0 v1 v2 v3 v4)
                (v0 ra v1)
                (v1 ra v0)
                (v2 ra)
                (v3 ra)
                (v4 ra)))

;; ------------------------------------------------------------
;; 图着色寄存器分配
;; ------------------------------------------------------------

(define-values (phys-asm regmap coloring)
  (allocate-registers-graph basic-asm interference))

(check-equal? regmap
              '((v0 . t1)
                (v1 . t0)
                (v2 . t0)
                (v3 . t0)
                (v4 . t0)))

(check-equal? coloring
              '(coloring
                ((a0 . a0)
                 (ra . ra)
                 (v0 . t1)
                 (v1 . t0)
                 (v2 . t0)
                 (v3 . t0)
                 (v4 . t0))))

(check-equal? phys-asm
              '((label main)
                (addi t1 x0 0)
                (addi t0 x0 1)
                (bge t1 t0 L0)
                (addi t0 x0 42)
                (addi t0 t0 0)
                (jal x0 L1)
                (label L0)
                (addi t0 x0 7)
                (addi t0 t0 0)
                (label L1)
                (addi a0 t0 0)
                (jalr x0 ra 0)))

;; ------------------------------------------------------------
;; layout
;; ------------------------------------------------------------

(define-values (labels resolved)
  (layout phys-asm))

(check-equal? labels
              '((main . 0)
                (L0 . 24)
                (L1 . 32)))

(check-equal? resolved
              '((addi t1 x0 0)
                (addi t0 x0 1)
                (bge t1 t0 16)
                (addi t0 x0 42)
                (addi t0 t0 0)
                (jal x0 12)
                (addi t0 x0 7)
                (addi t0 t0 0)
                (addi a0 t0 0)
                (jalr x0 ra 0)))

;; ------------------------------------------------------------
;; 端到端
;; ------------------------------------------------------------

(define-values (name program _asm _cfg _live _interference _regmap _coloring
                        compiled-labels _resolved)
  (compile-asm (cons 'asm basic-asm)))

(check-equal? name 'main)
(check-equal? compiled-labels labels)
(check-equal? program
              '(program
                (func main
                      (labels ((main . 0)
                               (L0 . 24)
                               (L1 . 32)))
                      (code
                       (addi t1 x0 0)
                       (addi t0 x0 1)
                       (bge t1 t0 16)
                       (addi t0 x0 42)
                       (addi t0 t0 0)
                       (jal x0 12)
                       (addi t0 x0 7)
                       (addi t0 t0 0)
                       (addi a0 t0 0)
                       (jalr x0 ra 0)))))
