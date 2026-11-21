#lang racket
;;; ir/scratch.rkt
;;;
;;; scratch 的共享形状和取用逻辑。
;;;
;;; 形状：
;;;   (scratch (native xN) ...)     ; 0 个或多个
;;;
;;; 约定：
;;;   - scratch 是 allocation 的单独输出，不是 vreg 条目；
;;;   - 同一个 scratch 寄存器不能重复列出；
;;;   - 各阶段只从 pool 里取，不自己挑物理寄存器；
;;;   - 不够时显式报错，由驱动增大 budget 后重跑。
;;;
;;; 这里不做 reserve / runtime contract 检查；那是 call-lower 等阶段的约束。

(require racket/list
         "../core/sexp.rkt"
         "shape.rkt")

(provide scratch-form?
         scratch-registers
         normalize-scratch
         func-scratch
         check-scratch-unique!
         scratch-exhausted?
         raise-scratch-exhausted
         make-scratch-pool
         scratch-pool?
         take-scratch!
         take-scratch-avoiding!
         scratch-pool-remaining
         scratch-pool-empty?)

;; (scratch (native xN) ...)
(define (scratch-form? x)
  (and (tagged? x 'scratch)
       (andmap physical-register? (cdr x))))

(define (scratch-registers scratch)
  (unless (scratch-form? scratch)
    (error 'scratch "malformed scratch: ~e" scratch))
  (cdr scratch))

;; 同一个寄存器列两次没有意义，而且会让 materialize 以为有两个 scratch。
(define (check-scratch-unique! regs [who 'scratch])
  (define seen (make-hash))
  (for ([reg (in-list regs)])
    (when (hash-has-key? seen reg)
      (error who "scratch register ~e is listed twice" reg))
    (hash-set! seen reg #t))
  regs)

;; 接受 (scratch ...) 或已经展开的 ((native xN) ...)。
;; 总是返回展开后的寄存器列表。
(define (normalize-scratch scratch [who 'scratch])
  (define regs
    (cond
      [(scratch-form? scratch) (cdr scratch)]
      [(and (list? scratch) (andmap physical-register? scratch)) scratch]
      [else (error who "malformed scratch: ~e" scratch)]))
  (check-scratch-unique! regs who))

;; 从 machine func 的顶层读 (scratch ...)；没有就是 '()。
(define (func-scratch func [who 'scratch])
  (define form
    (findf (lambda (x) (and (form? x) (eq? (car x) 'scratch)))
           (cddr func)))
  (if form
      (normalize-scratch form who)
      '()))

;; scratch 不足的专用异常；driver 用它做 scratch budget 反馈。
(struct scratch-exhausted exn:fail (who) #:transparent)

(define (raise-scratch-exhausted who)
  (raise (scratch-exhausted
          (format "~a: not enough scratch registers" who)
          (current-continuation-marks)
          who)))

;; ---------------------------------------------------------------------------
;; pool
;; ---------------------------------------------------------------------------

(struct scratch-pool (available) #:mutable)

(define (make-scratch-pool regs)
  (unless (and (list? regs) (andmap physical-register? regs))
    (error 'scratch "malformed scratch registers: ~e" regs))
  (scratch-pool regs))

(define (take-scratch! pool [who 'scratch])
  (unless (scratch-pool? pool)
    (error who "expected a scratch pool: ~e" pool))
  (match (scratch-pool-available pool)
    [(list reg rest ...)
     (set-scratch-pool-available! pool rest)
     reg]
    ['()
     (raise-scratch-exhausted who)]))

;; 取一个不在 avoid 里的 scratch；被跳过的寄存器保留在 pool 里。
;; 用于 call-lower：已经放在寄存器里的 call 参数不能被自己的 scratch 覆盖。
(define (take-scratch-avoiding! pool avoid [who 'scratch])
  (unless (scratch-pool? pool)
    (error who "expected a scratch pool: ~e" pool))
  (define avoid-set
    (for/hash ([reg (in-list avoid)]) (values reg #t)))
  (let loop ([remaining (scratch-pool-remaining pool)]
             [kept '()])
    (match remaining
      ['()
       (raise-scratch-exhausted who)]
      [(cons reg rest)
       (if (hash-has-key? avoid-set reg)
           (loop rest (cons reg kept))
           (begin
             (set-scratch-pool-available! pool (append (reverse kept) rest))
             reg))])))

(define (scratch-pool-remaining pool)
  (unless (scratch-pool? pool)
    (error 'scratch "expected a scratch pool: ~e" pool))
  (scratch-pool-available pool))

(define (scratch-pool-empty? pool)
  (null? (scratch-pool-remaining pool)))
