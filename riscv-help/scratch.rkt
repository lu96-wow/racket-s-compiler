#lang racket/base

;; ============================================================
;; scratch 寄存器参数处理
;; ============================================================

(require racket/list)

(define (scratch-list scratch)
  (cond
    [(not scratch) '()]
    [(list? scratch) scratch]
    [else (list scratch)]))

(define (take-scratch! who regs n)
  (unless (>= (length regs) n)
    (error who
           "need ~a scratch register(s), got ~a"
           n regs))
  (take regs n))

(define (check-distinct! who regs)
  (unless (= (length regs)
             (length (remove-duplicates regs eq?)))
    (error who "scratch registers must be distinct: ~a" regs)))

(define (check-not-zero! who reg)
  (when (eq? reg 'zero)
    (error who "register 'zero cannot be used as a scratch/base here")))

(provide scratch-list
         take-scratch!
         check-distinct!
         check-not-zero!)
