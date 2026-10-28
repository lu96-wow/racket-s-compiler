#lang racket
;;; encode/syntax/plan.rkt
;;;
;;; 把两个局部来源组合成一个语法计划:
;;;
;;;   direct.rkt  特殊形式 (fence / fence.tso)
;;;   order.rkt   普通操作数位置表
;;;
;;; insn.rkt 只依赖这里的 syntax-plan, 不直接知道 order/direct 的区别。
;;; 这样以后加 vector / CSR / FPR 语法时, 仍然只在对应局部模块里扩展。

(require "../../../riscv-asm/generated/lib/info/struct.rkt"
         "order.rkt"
         "direct.rkt")

(provide syntax-plan?
         syntax-plan-source
         syntax-plan-arities
         syntax-plan-arity
         syntax-plan-has-flags?
         syntax-plan-build
         syntax-plan-apply
         syntax-plan-for)

(struct syntax-plan
  (source        ; 'order | 'direct, 方便诊断
   arities       ; 接受的操作数个数, 第一个是 instruction-arity 的规范值
   has-flags?    ; 是否接受 .aq/.rl 后缀
   build)        ; (operands aq rl -> riscv-asm 函数参数)
  #:transparent)

(define (syntax-plan-arity plan)
  (car (syntax-plan-arities plan)))

(define (syntax-plan-apply plan target operands aq rl)
  ((syntax-plan-build plan) target operands aq rl))

(define (order->syntax-plan info)
  (define order (order-plan-of info))
  (and order
       (syntax-plan 'order
                    (list (order-plan-arity order))
                    (order-plan-has-flags? order)
                    (lambda (target operands aq rl)
                      (order-plan->args order target operands aq rl)))))

(define (direct->syntax-plan direct)
  (and direct
       (syntax-plan 'direct
                    (direct-plan-arities direct)
                    #f
                    (lambda (_target operands _aq _rl)
                      ((direct-plan-build direct) operands)))))

(define (syntax-plan-for info)
  (or (direct->syntax-plan (direct-plan-of (instruction-info-name info)))
      (order->syntax-plan info)))
