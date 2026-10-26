#lang racket
;;; L2/cfg.rkt
;;;
;;; 线性指令 -> 基本块图。
;;;
;;; 切块规则(leader):
;;;   - 程序开头
;;;   - 每个 (label L) 之后
;;;   - 每条 ends-block? 指令之后
;;; 连续的多个 (label ...) 归同一个块(块可以有多名字)。
;;;
;;; 边: 块的最后一条指令决定后继
;;;   分支        目标块 + 下一块
;;;   jal x0      目标块
;;;   jal ra      目标块 + 下一块
;;;   jalr        下一块(目标不可知, 记 indirect?)
;;;   ecall       下一块
;;;   ebreak      无
;;;   其他        下一块
;;;
;;; 目标指向别的段(屏障之后)的 label 时, 不算本段内的边, 但该 label 会被
;;; referenced-labels 记住, 作为可达性分析的根。

(require "insn.rkt")

(provide (struct-out block)
         (struct-out graph)
         build-cfg
         cfg-block-count
         cfg-reachable
         cfg->lines
         referenced-labels
         labels-of)

;; 一个基本块: 头部的若干 label + 指令 + 后继(块下标)
(struct block (labels insns successors) #:transparent)

;; 一张图: 块向量 + 有没有间接跳转
(struct graph (blocks indirect?) #:transparent)

;; ---------------------------------------------------------------------------
;; 建图
;; ---------------------------------------------------------------------------

(define (build-cfg items)
  ;; 1. 切块: 先收集 (labels . insns) 的逆序
  (define collected '())
  (define cur-labels '())
  (define cur-insns '())

  (define (flush!)
    (when (or (pair? cur-labels) (pair? cur-insns))
      (set! collected
            (cons (cons (reverse cur-labels) (reverse cur-insns)) collected))
      (set! cur-labels '())
      (set! cur-insns '())))

  (for ([it (in-list items)])
    (cond
      [(label-form? it)
       (when (pair? cur-insns) (flush!))          ; label 是新的 leader
       (set! cur-labels (cons (label-name it) cur-labels))]
      [else
       (set! cur-insns (cons it cur-insns))
       (when (ends-block? it) (flush!))]))

  (flush!)
  (define raw (reverse collected))

  ;; 2. label -> 块下标
  (define label->index (make-hash))
  (for ([entry (in-list raw)] [i (in-naturals)])
    (for ([l (in-list (car entry))])
      (hash-set! label->index l i)))

  ;; 3. 算每个块的后继
  (define n (length raw))
  (define blocks
    (for/vector ([entry (in-list raw)] [i (in-naturals)])
      (define insns (cdr entry))
      (define last-insn (and (pair? insns) (last insns)))
      (define fallthrough (and (< (add1 i) n) (add1 i)))
      (define (edge label) (hash-ref label->index label #f))
      (define (succs . xs) (filter values xs))
      (block (car entry)
             insns
             (cond
               [(branch-instruction? last-insn)
                (succs (edge (jump-target last-insn)) fallthrough)]
               [(unconditional-jump? last-insn)
                (succs (edge (jump-target last-insn)))]
               [(jump-instruction? last-insn)
                (succs (edge (jump-target last-insn)) fallthrough)]
               [(indirect-instruction? last-insn)
                (succs fallthrough)]
               [(and (trap-instruction? last-insn)
                     (eq? (car last-insn) 'ebreak))
                (succs)]
               [else (succs fallthrough)]))))

  (graph blocks
         (for/or ([it (in-list items)])
           (indirect-instruction? it))))

(define (cfg-block-count g) (vector-length (graph-blocks g)))

;; 一个块的所有名字
(define (labels-of b) (block-labels b))

;; ---------------------------------------------------------------------------
;; 分析
;; ---------------------------------------------------------------------------

;; 整段代码里被当成跳转/分支目标出现过的 label(含跨段的)
(define (referenced-labels items)
  (remove-duplicates
   (for/list ([it (in-list items)]
              #:when (or (branch-instruction? it) (jump-instruction? it)))
     (jump-target it))))

;; 从 roots 出发能走到的块下标(升序)
(define (cfg-reachable g roots)
  (define blocks (graph-blocks g))
  (define seen (make-vector (vector-length blocks) #f))
  (define (visit! i)
    (unless (vector-ref seen i)
      (vector-set! seen i #t)
      (for ([s (in-list (block-successors (vector-ref blocks i)))])
        (visit! s))))
  (for ([r (in-list roots)])
    (when (< r (vector-length blocks)) (visit! r)))
  (for/list ([i (in-range (vector-length blocks))]
             #:when (vector-ref seen i))
    i))

;; 给人看的图: 一行一个块
(define (cfg->lines g)
  (for/list ([b (in-vector (graph-blocks g))] [i (in-naturals)])
    (format "b~a labels=~s insns=~a succs=~s"
            i (block-labels b) (length (block-insns b)) (block-successors b))))
