#lang racket/base

;; ============================================================
;; scratch 寄存器参数处理
;; ============================================================

(require racket/list
         "registers.rkt")

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
  ;; 已知物理寄存器按编号判断；未知符号/虚拟寄存器按 eq? 判断。
  (define keys
    (for/list ([reg (in-list regs)])
      (or (register->number reg) reg)))
  (unless (= (length keys)
             (length (remove-duplicates keys eq?)))
    (error who "scratch registers must be distinct: ~a" regs)))

(define (check-not-zero! who reg)
  (when (zero-register? reg)
    (error who "register zero cannot be used as a scratch/base here")))

(provide scratch-list
         take-scratch!
         check-distinct!
         check-not-zero!)
