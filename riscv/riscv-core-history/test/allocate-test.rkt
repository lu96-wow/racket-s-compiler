#lang racket
;;; test/allocate-test.rkt
;;;
;;; 第一版真实分配：liveness -> 干涉图 -> 着色 -> spill。
;;; 输出必须能直接通过 verify-allocation 并进入 materialize。

(require rackunit
         racket/list
         "../core/sexp.rkt"
         "../ir/allocate.rkt"
         "../ir/allocation.rkt"
         "../ir/materialize.rkt"
         "../ir/frame.rkt"
         "../ir/lower.rkt"
         "../ir/verify-machine.rkt"
         "../examples/minimal.rkt"
         "../examples/stack-local.rkt")

(define (allocate-ok func #:scratch-budget [scratch-budget 0]
                     #:forbidden [forbidden '()])
  (define-values (allocation scratch)
    (allocate-func func
                   #:scratch-budget scratch-budget
                   #:forbidden forbidden))
  (check-true (allocation-form? allocation))
  (check-true (scratch-form? scratch))
  (verify-allocation func allocation scratch)
  (values allocation scratch))

(define (contains-vreg? x)
  (cond
    [(vreg? x) #t]
    [(list? x) (ormap contains-vreg? x)]
    [else #f]))

;; ---------------------------------------------------------------------------
;; 基础
;; ---------------------------------------------------------------------------

(test-case "minimal allocates three pairwise-interfering vregs"
  (define-values (allocation scratch) (allocate-ok minimal-virtual))
  (check-equal? allocation
                '(allocation
                   (($ a) (native x1))
                   (($ b) (native x2))
                   (($ t) (native x3))))
  (check-equal? scratch '(scratch)))

(test-case "stack-local puts address-taken vreg in slot 0"
  (define-values (allocation scratch) (allocate-ok stack-local-virtual))
  (check-equal? allocation
                '(allocation
                   (($ x) (slot 0))
                   (($ p) (native x1))
                   (($ t) (native x2))))
  (check-equal? scratch '(scratch)))

(test-case "scratch budget reserves registers before coloring"
  (define-values (allocation scratch)
    (allocate-ok minimal-virtual #:scratch-budget 2))
  (check-equal? scratch '(scratch (native x1) (native x2)))
  (check-equal? allocation
                '(allocation
                   (($ a) (native x3))
                   (($ b) (native x4))
                   (($ t) (native x5)))))

(test-case "forbidden registers are not allocated"
  (define-values (allocation _)
    (allocate-ok minimal-virtual #:forbidden '((native x1) (native x2))))
  (check-equal? allocation
                '(allocation
                   (($ a) (native x3))
                   (($ b) (native x4))
                   (($ t) (native x5)))))

;; ---------------------------------------------------------------------------
;; pin / reserve / clobber
;; ---------------------------------------------------------------------------

(test-case "pin fixes the register and interferes with neighbors"
  (define func
    '(func (main)
       (vregs
         (($ a) (b8))
         (($ b) (b8))
         (($ t) (b64)))
       (alloc
         (pin ($ a) (native x20)))
       (entry b0)
       (block b0
         (add ($ t) ($ a) ($ b))
         (term (return ($ t))))))
  (define-values (allocation _) (allocate-ok func))
  (check-equal? allocation
                '(allocation
                   (($ a) (native x20))
                   (($ b) (native x1))
                   (($ t) (native x2)))))

(test-case "reserve and clobber are avoided by ordinary vregs"
  (define func
    '(func (main)
       (vregs
         (($ a) (b8))
         (($ b) (b8))
         (($ t) (b64)))
       (alloc
         (reserve (native x1))
         (clobber (native x2)))
       (entry b0)
       (block b0
         (add ($ t) ($ a) ($ b))
         (term (return ($ t))))))
  (define-values (allocation _) (allocate-ok func))
  (check-equal? allocation
                '(allocation
                   (($ a) (native x3))
                   (($ b) (native x4))
                   (($ t) (native x5)))))

(test-case "a clobbered register is not chosen for scratch"
  (define func
    '(func (main)
       (vregs
         (($ a) (b8))
         (($ b) (b8))
         (($ t) (b64)))
       (alloc
         (clobber (native x1)))
       (entry b0)
       (block b0
         (add ($ t) ($ a) ($ b))
         (term (return ($ t))))))
  (define-values (allocation scratch)
    (allocate-ok func #:scratch-budget 1))
  (check-equal? scratch '(scratch (native x2)))
  (check-equal? (allocation-location allocation '($ a)) '(native x3)))

;; ---------------------------------------------------------------------------
;; 错误
;; ---------------------------------------------------------------------------

(test-case "two interfering pins cannot share a register"
  (define func
    '(func (main)
       (vregs
         (($ a) (b8))
         (($ b) (b8))
         (($ t) (b64)))
       (alloc
         (pin ($ a) (native x10))
         (pin ($ b) (native x10)))
       (entry b0)
       (block b0
         (add ($ t) ($ a) ($ b))
         (term (return ($ t))))))
  (check-exn #rx"pinned to .* but interfere"
             (lambda () (allocate-func func))))

(test-case "pinning to x0 is rejected"
  (define func
    '(func (main)
       (vregs
         (($ a) (b8))
         (($ b) (b8))
         (($ t) (b64)))
       (alloc
         (pin ($ a) (native x0)))
       (entry b0)
       (block b0
         (add ($ t) ($ a) ($ b))
         (term (return ($ t))))))
  (check-exn #rx"cannot be pinned to x0"
             (lambda () (allocate-func func))))

(test-case "scratch budget larger than the register file is rejected"
  (check-exn #rx"not enough registers for scratch budget"
             (lambda () (allocate-func minimal-virtual #:scratch-budget 32))))

;; ---------------------------------------------------------------------------
;; spill + 完整 pipeline
;; ---------------------------------------------------------------------------

(test-case "all spilled function materializes and lowers with two scratch"
  (define reserves
    (for/list ([i (in-range 3 32)])
      (list 'reserve (list 'native (string->symbol (format "x~a" i))))))
  (define func
    (list 'func
          '(main)
          '(vregs
            (($ a) (b64))
            (($ b) (b64))
            (($ t) (b64)))
          (cons 'alloc reserves)
          '(entry b0)
          '(block b0
            (add ($ t) ($ a) ($ b))
            (term (return 0)))))

  (define-values (allocation scratch)
    (allocate-ok func #:scratch-budget 2))
  (check-equal? scratch '(scratch (native x1) (native x2)))
  (check-equal? allocation
                '(allocation
                   (($ a) (slot 0))
                   (($ b) (slot 1))
                   (($ t) (slot 2))))

  (define machine (materialize-func func allocation #:scratch scratch))
  (check-false (contains-vreg? machine))
  (define frame (frame-layout func allocation))
  (define lowered (lower-func machine frame #:scratch scratch))
  (verify-machine (list lowered))
  (check-false (contains-vreg? lowered)))

(test-case "minimal runs allocate -> materialize -> frame -> lower -> verify"
  (define-values (allocation scratch)
    (allocate-ok minimal-virtual #:scratch-budget 1))
  (define machine (materialize-func minimal-virtual allocation #:scratch scratch))
  (define frame (frame-layout minimal-virtual allocation))
  (define lowered (lower-func machine frame #:scratch scratch))
  (verify-machine (list lowered))
  (check-false (contains-vreg? lowered)))
