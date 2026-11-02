#lang racket
;;; amd64-help/scratch.rkt
;;;
;;; Scratch-register rules for future far/trampoline expansions.  This module
;;; only validates registers; it does not allocate them and does not emit code.

(require "../amd64-asm/registers.rkt")

(provide scratch-list
         check-distinct!
         check-scratch-register!
         take-scratch!)

;; No default scratch set here.  Caller-saved/preserved registers are an ABI
;; policy; the caller (e.g. loko-compatibility) must pass an explicit list.

(define (scratch-list scratch)
  (cond
    [(not scratch) '()]
    [(symbol? scratch) (list scratch)]
    [(and (list? scratch) (andmap symbol? scratch)) scratch]
    [else
     (error 'scratch-list "scratch must be #f, a symbol, or a list of symbols: ~e"
            scratch)]))

(define (check-scratch-register! who r)
  (define reg (lookup-register r #f))
  (unless (and reg (gpr-register? reg))
    (error who "scratch must be a GPR: ~e" r))
  (when (eq? (reg-name reg) 'rsp)
    (error who "rsp cannot be used as scratch: ~e" r))
  reg)

(define (check-distinct! who regs)
  (unless (= (length regs) (length (remove-duplicates regs eq?)))
    (error who "scratch registers must be distinct: ~e" regs))
  (for ([r (in-list regs)]) (check-scratch-register! who r))
  (void))

(define (take-scratch! who regs n)
  (unless (>= (length regs) n)
    (error who "need ~a scratch register(s), got ~e" n regs))
  (define picked (take regs n))
  (check-distinct! who picked)
  picked)
