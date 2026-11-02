#lang racket
;;; encode/syntax/native.rkt
;;;
;;; riscv-opcodes native 语法计划。
;;;
;;; native 顺序 = instruction-info-operands 的顺序（去掉 aq / rl）。
;;; aq / rl 仍然用助记符后缀，不占表面操作数。
;;;
;;; 这里不做重排：native 就是生成函数的参数顺序。
;;; GAS 顺序在 gas-syntax/ 里单独处理，不进入编码层。

(require "../../../riscv-asm/generated/lib/info/struct.rkt"
         "operand-kind.rkt")

(provide native-plan-of
         native-plan-arity
         native-plan-has-flags?
         native-plan->args)

;; 一个 operand token 怎么解释。
;; 目前只有 csr / zimm5 需要特殊处理；其余都交给 GPR/整数。
(define (token-kind token)
  (cond
    [(string=? token "csr") 'csr]
    [(string=? token "zimm5") 'zimm5]
    [else 'plain]))

;; plan = ((kind source-index) ... | 'aq | 'rl)
;;
;; source-index 是去掉 aq/rl 后的表面操作数位置。
(define (native-plan-of info)
  (define tokens (instruction-info-operands info))
  (define-values (rev-plan _next)
    (for/fold ([rev '()] [next 0])
              ([tok (in-list tokens)])
      (cond
        [(string=? tok "aq") (values (cons 'aq rev) next)]
        [(string=? tok "rl") (values (cons 'rl rev) next)]
        [else
         (values (cons (list (token-kind tok) next) rev) (add1 next))])))
  (reverse rev-plan))

(define (plan-position p)
  (cond
    [(exact-integer? p) p]
    [(and (pair? p) (exact-integer? (cadr p))) (cadr p)]
    [else #f]))

(define (native-plan-arity plan)
  (define xs (filter values (map plan-position plan)))
  (if (null? xs) 0 (add1 (apply max xs))))

(define (native-plan-has-flags? plan)
  (and (ormap (lambda (p) (memq p '(aq rl))) plan) #t))

(define (native-plan->args plan target operands aq rl)
  (for/list ([p (in-list plan)])
    (cond
      [(eq? p 'aq) aq]
      [(eq? p 'rl) rl]
      [(exact-integer? p) (operand-kind-value target 'plain (list-ref operands p))]
      [(pair? p) (operand-kind-value target (car p) (list-ref operands (cadr p)))]
      [else (error 'encode-instruction "bad native-plan entry: ~e" p)])))
