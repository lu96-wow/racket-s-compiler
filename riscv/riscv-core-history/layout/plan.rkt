#lang racket
;;; layout/plan.rkt
;;;
;;; layout-plan 只决定：
;;;   - block 的物理顺序；
;;;   - 哪个后继是 fallthrough。
;;;
;;; 它不决定 b/j 的形式、字节数、island、scratch。那些在 layout-relax。
;;; 输入是已经通过 verify 的 CFG；这里不重新验证 op/vreg。
;;;
;;; 第一版 policy 只支持 text order：
;;;   - entry 放最前；
;;;   - 其余 block 保持 CFG 的文本顺序。

(require racket/list
         "../core/sexp.rkt"
         "../ir/cfg.rkt"
         "policy.rkt")

(provide (struct-out layout-plan)
         plan-layout
         layout-plan->sexp)

(struct layout-plan
  (name     ; 函数全局链
   entry    ; 入口 block
   order    ; 物理 block 顺序
   fallthrough) ; hash block -> 下一块 或 #f
  #:transparent)

(define (plan-layout cfg [policy default-layout-policy])
  (unless (cfg? cfg)
    (error 'layout-plan "expected a cfg: ~e" cfg))
  (unless (policy-valid? policy)
    (error 'layout-plan "invalid layout policy: ~e" policy))
  (case (layout-policy-order policy)
    [(text) (void)]
    [else
     (error 'layout-plan
            "block order strategy ~a is not implemented yet"
            (layout-policy-order policy))])

  (define text-order (cfg-blocks cfg))
  (define entry (cfg-entry cfg))
  (define order
    (cons entry (remove entry text-order)))

  (define successors (cfg-successors cfg))
  (define fallthrough
    (for/hash ([block (in-list order)]
               [index (in-naturals)])
      (define next
        (and (< (add1 index) (length order))
             (list-ref order (add1 index))))
      (define succ
        (hash-ref successors block '()))
      (values block
              (and next (member next succ) next))))

  (layout-plan (cfg-name cfg) entry order fallthrough))

;; 调试/测试用：稳定的 s-exp 视图。
(define (layout-plan->sexp plan)
  (list 'layout-plan
        (list 'name (layout-plan-name plan))
        (list 'entry (layout-plan-entry plan))
        (cons 'order (layout-plan-order plan))
        (cons 'fallthrough
              (for/list ([block (in-list (layout-plan-order plan))]
                         #:when (hash-ref (layout-plan-fallthrough plan) block #f))
                (list block (hash-ref (layout-plan-fallthrough plan) block))))))
