#lang racket
;;; test/layout-plan-test.rkt
;;;
;;; layout policy 和 layout-plan：
;;;   - block 顺序；
;;;   - entry 放最前；
;;;   - fallthrough 选择。
;;;
;;; 这里不测 b/j 形式、island、scratch；那些属于 layout-relax。

(require rackunit
         "../ir/verify.rkt"
         "../ir/cfg.rkt"
         "../layout/policy.rkt"
         "../layout/plan.rkt"
         "../examples/minimal.rkt"
         "../examples/branch.rkt")

;; ---------------------------------------------------------------------------
;; policy
;; ---------------------------------------------------------------------------

(test-case "default layout policy"
  (check-true (policy-valid? default-layout-policy))
  (check-equal? (layout-policy-order default-layout-policy) 'text)
  (check-equal? (layout-policy-far-branch default-layout-policy) 'inline)
  (check-equal? (layout-policy-far-jump default-layout-policy) 'inline)
  (check-equal? (layout-policy-scratch default-layout-policy) 'feedback)
  (check-false (layout-policy-rvc? default-layout-policy)))

(test-case "policy rejects unknown strategy"
  (check-exn exn:fail?
             (lambda () (make-layout-policy #:order 'unknown)))
  (check-exn exn:fail?
             (lambda () (make-layout-policy #:far-branch 'unknown))))

;; ---------------------------------------------------------------------------
;; plan
;; ---------------------------------------------------------------------------

(test-case "minimal function has a single block"
  (define cfg (build-cfg minimal-virtual))
  (define plan (plan-layout cfg))
  (check-equal? (layout-plan-name plan) '(main))
  (check-equal? (layout-plan-entry plan) 'b0)
  (check-equal? (layout-plan-order plan) '(b0))
  (check-false (hash-ref (layout-plan-fallthrough plan) 'b0))
  (check-equal? (layout-plan->sexp plan)
                '(layout-plan
                   (name (main))
                   (entry b0)
                   (order b0)
                   (fallthrough))))

(test-case "branch function chooses the next block as fallthrough"
  (define cfg (build-cfg branch-virtual))
  (define plan (plan-layout cfg))
  (check-equal? (layout-plan-order plan) '(b0 b1 b2))
  (check-equal? (hash-ref (layout-plan-fallthrough plan) 'b0) 'b1)
  (check-equal? (hash-ref (layout-plan-fallthrough plan) 'b1) 'b2)
  (check-false (hash-ref (layout-plan-fallthrough plan) 'b2))
  (check-equal? (layout-plan->sexp plan)
                '(layout-plan
                   (name (main))
                   (entry b0)
                   (order b0 b1 b2)
                   (fallthrough (b0 b1) (b1 b2)))))

(test-case "entry is moved to the front"
  (define func
    '(func (main)
       (vregs)
       (entry b0)
       (block b1
         (term (return 0)))
       (block b0
         (term (jump b1)))))
  (verify-virtual (list func))
  (define plan (plan-layout (build-cfg func)))
  (check-equal? (layout-plan-order plan) '(b0 b1))
  (check-equal? (hash-ref (layout-plan-fallthrough plan) 'b0) 'b1)
  (check-false (hash-ref (layout-plan-fallthrough plan) 'b1)))

(test-case "jump target that is not next has no fallthrough"
  (define func
    '(func (main)
       (vregs)
       (entry b0)
       (block b0
         (term (jump b2)))
       (block b1
         (term (return 0)))
       (block b2
         (term (return 0)))))
  (verify-virtual (list func))
  (define plan (plan-layout (build-cfg func)))
  (check-equal? (layout-plan-order plan) '(b0 b1 b2))
  (for ([block (in-list '(b0 b1 b2))])
    (check-false (hash-ref (layout-plan-fallthrough plan) block)))
  (check-equal? (layout-plan->sexp plan)
                '(layout-plan
                   (name (main))
                   (entry b0)
                   (order b0 b1 b2)
                   (fallthrough))))

(test-case "a branch with neither successor next has no fallthrough"
  (define func
    '(func (main)
       (vregs)
       (entry b0)
       (block b0
         (term (branch (eq 0 0) b2 b3)))
       (block b1
         (term (return 0)))
       (block b2
         (term (return 0)))
       (block b3
         (term (return 0)))))
  (verify-virtual (list func))
  (define plan (plan-layout (build-cfg func)))
  (check-equal? (layout-plan-order plan) '(b0 b1 b2 b3))
  (for ([block (in-list '(b0 b1 b2 b3))])
    (check-false (hash-ref (layout-plan-fallthrough plan) block))))

(test-case "unreachable blocks stay in the plan"
  (define func
    '(func (main)
       (vregs)
       (entry b0)
       (block b0
         (term (return 0)))
       (block dead
         (term (return 0)))))
  (verify-virtual (list func))
  (define plan (plan-layout (build-cfg func)))
  (check-equal? (layout-plan-order plan) '(b0 dead))
  (check-false (hash-ref (layout-plan-fallthrough plan) 'b0))
  (check-false (hash-ref (layout-plan-fallthrough plan) 'dead)))

(test-case "unsupported block order strategy is explicit"
  (check-exn #rx"not implemented"
             (lambda ()
               (plan-layout (build-cfg minimal-virtual)
                            (make-layout-policy #:order 'greedy)))))
