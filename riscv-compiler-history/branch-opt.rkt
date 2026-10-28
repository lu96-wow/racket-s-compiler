#lang racket/base

;; ============================================================
;; block 分支分析/优化
;;
;; 输入：CFG
;; 输出：优化后的 asm
;;
;; 当前两条规则：
;;   1. 删除不可达 block
;;   2. 如果无条件跳转的目标就是下一个 block，删除该跳转
;; ============================================================

(require racket/list
         "asm.rkt"
         "cfg.rkt")

(provide optimize-branches
         reachable-block-ids)

(define (reachable-block-ids cfg)
  (define seen (make-hash))
  (let loop ([work (list (cfg-entry cfg))])
    (cond
      [(null? work)
       (hash-keys seen)]
      [else
       (define id (car work))
       (cond
         [(hash-has-key? seen id)
          (loop (cdr work))]
         [else
          (hash-set! seen id #t)
          (loop (append (cdr work)
                        (cfg-succ-of cfg id)))])])))

(define (jump-target-block cfg instruction)
  (cfg-target-block cfg (list-ref instruction 2)))

(define (remove-jump-to-next blocks cfg)
  (for/list ([block (in-list blocks)]
             [next (in-list (append (cdr blocks) (list #f)))])
    (define insns (block-insns block))
    (define insns*
      (cond
        [(null? insns) insns]
        [else
         (define last-insn (last insns))
         (if (and next
                  (unconditional-jump? last-insn)
                  (eq? (jump-target-block cfg last-insn) (block-id next)))
             (drop-right insns 1)
             insns)]))
    (list 'block
          (block-id block)
          (list 'labels (block-labels block))
          (list 'insns insns*))))

(define (block->asm block)
  (append
   (for/list ([label (in-list (block-labels block))])
     (list 'label label))
   (block-insns block)))

(define (optimize-branches cfg)
  (define reachable (reachable-block-ids cfg))
  (define blocks
    (filter (lambda (block)
              (memq (block-id block) reachable))
            (cfg-blocks cfg)))
  (define optimized
    (remove-jump-to-next blocks cfg))
  (append-map block->asm optimized))
