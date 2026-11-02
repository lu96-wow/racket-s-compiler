#lang racket
;;; encode/syntax/plan.rkt
;;;
;;; 把两个局部来源组合成一个语法计划:
;;;
;;;   direct.rkt  特殊形式 (fence / fence.tso / fence.i)
;;;   native.rkt  riscv-opcodes native 顺序
;;;
;;; 编码层只认 native。GAS 是可选的前端重写层（gas-syntax/），
;;; 不在这里出现，也不形成第二个编码分支。

(require "../../../riscv-asm/generated/lib/info/struct.rkt"
         "native.rkt"
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
  (source        ; 'native | 'direct, 方便诊断
   arities       ; 接受的操作数个数, 第一个是 instruction-arity 的规范值
   has-flags?    ; 是否接受 .aq/.rl 后缀
   build)        ; (target operands aq rl -> riscv-asm 函数参数)
  #:transparent)

(define (syntax-plan-arity plan)
  (car (syntax-plan-arities plan)))

(define (syntax-plan-apply plan target operands aq rl)
  ((syntax-plan-build plan) target operands aq rl))

(define (native->syntax-plan info)
  (define plan (native-plan-of info))
  (syntax-plan 'native
               (list (native-plan-arity plan))
               (native-plan-has-flags? plan)
               (lambda (target operands aq rl)
                 (native-plan->args plan target operands aq rl))))

(define (direct->syntax-plan direct)
  (and direct
       (syntax-plan 'direct
                    (direct-plan-arities direct)
                    #f
                    (lambda (_target operands _aq _rl)
                      ((direct-plan-build direct) operands)))))

(define (syntax-plan-for info)
  (or (direct->syntax-plan (direct-plan-of (instruction-info-name info)))
      (native->syntax-plan info)))
