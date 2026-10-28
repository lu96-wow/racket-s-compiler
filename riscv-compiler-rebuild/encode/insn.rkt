#lang racket
;;; encode/insn.rkt
;;;
;;; 一条真指令 -> 指令字。编码本身交给 riscv-asm 生成的 rebuilt 模块:
;;; 那里已经含全部位域检查(立即数范围、压缩寄存器约束、aq/rl 值域)。
;;;
;;; 本层是**组合点**, 不放大表:
;;;
;;;   syntax/suffix.rkt   .aq / .rl / .aqrl
;;;   syntax/operand.rkt  操作数值 (GPR / 整数)
;;;   syntax/order.rkt    普通指令: s-exp 位置 -> 函数参数位置
;;;   syntax/direct.rkt   特殊形式: fence / fence.tso
;;;   syntax/plan.rkt     把 order/direct 组合成 syntax-plan
;;;
;;; 真正的编码事实仍然在 riscv-asm 的 instruction-info 和 generated 模块里。
;;; 这里只负责:
;;;   1. 查 instruction-info
;;;   2. 选择一个 syntax-plan
;;;   3. 把 plan 产生的参数交给 generated 指令函数
;;;
;;; 范围检查不在这里: 越界由 riscv-asm 抛错(它就是"变二进制"那一步)。

(require "../../riscv-asm/generated/lib/instruction_paths.rkt"
         "../../riscv-asm/generated/lib/info/struct.rkt"
         "../../riscv-asm/generated/lib/info/lookup.rkt"
         "../target.rkt"
         "syntax/suffix.rkt"
         "syntax/plan.rkt")

(provide encode-instruction
         instruction-arity
         known-instruction?
         split-aqrl)

;; ---------------------------------------------------------------------------
;; 查表 (缓存)
;; ---------------------------------------------------------------------------

(define info-cache (make-hash))

(define (lookup-instruction name)
  (hash-ref! info-cache name
             (lambda ()
               (and (pair? (instruction-info-candidates target-extensions name))
                    (resolve-instruction-info target-extensions name)))))

(define (known-instruction? name) (and (lookup-instruction name) #t))

(define proc-cache (make-hash))

(define (instruction-proc info)
  (define ext (instruction-info-extension info))
  (define name (instruction-info-name info))
  (hash-ref! proc-cache (cons ext name)
             (lambda ()
               (dynamic-require `(file ,(rebuilt-instruction-path ext)) name))))

;; ---------------------------------------------------------------------------
;; 元数
;; ---------------------------------------------------------------------------

(define (instruction-arity name)
  (define-values (base _aq _rl) (split-aqrl name))
  (define info (lookup-instruction base))
  (and info
       (let ([plan (syntax-plan-for info)])
         (and plan (syntax-plan-canonical-arity plan)))))

;; ---------------------------------------------------------------------------
;; 编码
;;   operands 里可以是寄存器名(x0/zero/a0…)或已经解析好的整数。
;;   立即数/偏移一律是整数。
;; ---------------------------------------------------------------------------

(define (encode-instruction name operands)
  (define-values (base aq rl) (split-aqrl name))
  (define info (or (lookup-instruction base)
                   (error 'encode-instruction "unknown instruction: ~a" name)))
  (define plan (or (syntax-plan-for info)
                   (error 'encode-instruction
                          "no operand syntax for ~a (operands ~s)"
                          base (instruction-info-operands info))))
  (when (and (positive? (+ aq rl)) (not (syntax-plan-has-flags? plan)))
    (error 'encode-instruction "~a does not take .aq/.rl" name))
  (define arities (syntax-plan-arities plan))
  (unless (memv (length operands) arities)
    (error 'encode-instruction
           "~a takes ~a operand(s), got ~a: ~e"
           base arities (length operands) operands))
  (values (apply (instruction-proc info) (syntax-plan-apply plan operands aq rl))
          (quotient (instruction-info-width info) 8)))
