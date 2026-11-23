#lang racket
;;; frontend/blockify.rkt
;;;
;;; 参考前端：扁平 item -> code(blocks + falls)。
;;;
;;; 这不是 backend 的 CFG 分析。它只做前端必须做的结构决定：
;;;   - 哪些 label 是块头（控制转移目标）
;;;   - 控制转移之后开新块
;;;   - 哪些块在物理顺序上必须紧挨着（falls）
;;;
;;; 不做 succ / root? / 可达性 / DCE。这些属于前端的语义层。
;;; 测试和示例可以用它构造 code；backend 本身不调用它。

(require "../sexp.rkt"
         "../code.rkt"
         "../code/insn.rkt")

(provide blockify
         code-of)

;; 被直接控制转移当成目标引用过的链。
(define (referenced-labels items)
  (remove-duplicates
   (for/list ([it (in-list items)]
              #:when (or (branch-instruction? it) (jump-instruction? it))
              #:do [(define p (normalize-path (jump-target it)))]
              #:when p)
     p)))

(define (blockify items)
  (define items* (as-items items))
  (define targets (referenced-labels items*))
  (define collected '())
  (define cur-labels '())
  (define cur-insns '())

  (define (flush!)
    (when (or (pair? cur-labels) (pair? cur-insns))
      (set! collected
            (cons (cons (reverse cur-labels) (reverse cur-insns)) collected))
      (set! cur-labels '())
      (set! cur-insns '())))

  (for ([it (in-list items*)])
    (cond
      [(label-form? it)
       (define path (label-path it))
       (cond
         ;; 块开头(还没放 item): 归块头的多个名字
         [(null? cur-insns) (set! cur-labels (cons path cur-labels))]
         ;; 目标是 leader: 另起一块
         [(member path targets) (flush!) (set! cur-labels (list path))]
         ;; 非目标 label: 位置标记, 留在块里
         [else (set! cur-insns (cons it cur-insns))])]
      [else
       (set! cur-insns (cons it cur-insns))
       (when (ends-block? it) (flush!))]))

  (flush!)
  (define raw (reverse collected))
  (define blocks
    (for/list ([entry (in-list raw)])
      (make-block (car entry) (cdr entry))))
  (define falls
    (for/list ([b (in-list blocks)]
               [i (in-naturals)]
               #:when (< (add1 i) (length blocks))
               #:do [(define last-insn (and (pair? (block-items b))
                                            (last (block-items b))))]
               #:when (falls-through? last-insn))
      (make-fall i (add1 i))))
  (make-code blocks falls))

(define code-of blockify)
