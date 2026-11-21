#lang racket
;;; test/cfg-test.rkt
;;;
;;; Step 2：从 block + term 抽 CFG。

(require rackunit
         "../ir/cfg.rkt"
         "../ir/verify.rkt"
         "../examples/minimal.rkt"
         "../examples/branch.rkt"
         "../examples/module.rkt")

(define (sorted-symbols xs)
  (sort xs symbol<?))

;; ---------------------------------------------------------------------------
;; term-successors
;; ---------------------------------------------------------------------------

(test-case "term-successors follows term shape"
  (check-equal? (term-successors '(term (jump b1))) '(b1))
  (check-equal? (term-successors '(term (branch (eq 0 0) b1 b2))) '(b1 b2))
  (check-equal? (term-successors '(term (return ($ a)))) '())
  (check-equal? (term-successors '(term (trap))) '())
  (check-exn exn:fail? (lambda () (term-successors '(term (fallthrough b1))))))

;; ---------------------------------------------------------------------------
;; 单函数
;; ---------------------------------------------------------------------------

(test-case "minimal function has one block and no edges"
  (define c (build-cfg minimal-virtual))
  (check-equal? (cfg-name c) '(main))
  (check-equal? (cfg-entry c) 'b0)
  (check-equal? (cfg-blocks c) '(b0))
  (check-equal? (hash-ref (cfg-successors c) 'b0) '())
  (check-equal? (hash-ref (cfg-predecessors c) 'b0) '())
  (check-equal? (reachable-blocks c) '(b0))
  (check-equal? (unreachable-blocks c) '())
  (check-true (cfg-all-reachable? c)))

(test-case "branch function exposes both successors in source order"
  (define c (build-cfg branch-virtual))
  (check-equal? (cfg-blocks c) '(b0 b1 b2))
  (check-equal? (hash-ref (cfg-successors c) 'b0) '(b2 b1))
  (check-equal? (hash-ref (cfg-successors c) 'b1) '(b2))
  (check-equal? (hash-ref (cfg-successors c) 'b2) '())
  (check-equal? (hash-ref (cfg-predecessors c) 'b0) '())
  (check-equal? (hash-ref (cfg-predecessors c) 'b1) '(b0))
  (check-equal? (hash-ref (cfg-predecessors c) 'b2) '(b0 b1))
  (check-equal? (sorted-symbols (reachable-blocks c)) '(b0 b1 b2))
  (check-true (cfg-all-reachable? c)))

(test-case "unreachable blocks are reported, not deleted"
  (define func
    '(func (main)
       (vregs)
       (entry b0)
       (block b0
         (term (return 0)))
       (block dead
         (term (return 0)))))
  (verify-virtual (list func))
  (define c (build-cfg func))
  (check-equal? (cfg-blocks c) '(b0 dead))
  (check-equal? (reachable-blocks c) '(b0))
  (check-equal? (unreachable-blocks c) '(dead))
  (check-false (cfg-all-reachable? c)))

(test-case "a cycle is reachable"
  (define func
    '(func (main)
       (vregs)
       (entry b0)
       (block b0
         (term (jump b1)))
       (block b1
         (term (jump b0)))))
  (verify-virtual (list func))
  (define c (build-cfg func))
  (check-equal? (hash-ref (cfg-successors c) 'b0) '(b1))
  (check-equal? (hash-ref (cfg-successors c) 'b1) '(b0))
  (check-equal? (hash-ref (cfg-predecessors c) 'b0) '(b1))
  (check-equal? (hash-ref (cfg-predecessors c) 'b1) '(b0))
  (check-equal? (sorted-symbols (reachable-blocks c)) '(b0 b1))
  (check-true (cfg-all-reachable? c)))

;; ---------------------------------------------------------------------------
;; 多函数
;; ---------------------------------------------------------------------------

(test-case "build-program-cfg keeps one cfg per func"
  (define cs (build-program-cfg module-resolved))
  (check-equal? (map cfg-name cs)
                '((lib util f) (app main)))
  (for ([c (in-list cs)])
    (check-equal? (cfg-blocks c) '(b0))
    (check-true (cfg-all-reachable? c))))
