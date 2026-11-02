#lang racket
;;; gas-syntax/rewrite.rkt
;;;
;;; 可选的 GAS 表面语法 -> riscv-opcodes native 语法。
;;;
;;; 这一层只做表替换，不编码、不布局、不绑地址。
;;; 它可以完全不跑；默认流不包含它。
;;;
;;;   (beq a b L)          -> (beq L a b)
;;;   (sw t0 sp 8)         -> (sw 8 sp t0)
;;;   (csrrw a0 mstatus a1)-> (csrrw a0 a1 mstatus)
;;;   (amoadd.d.aqrl a0 a2 a1) -> (amoadd.d.aqrl a0 a1 a2)
;;;
;;; 不认识的形状原样透传，交给 native 层报错。

(require "../sexp.rkt"
         "../target.rkt"
         "../encode/syntax/suffix.rkt"
         "../../riscv-asm/generated/lib/info/struct.rkt"
         "../../riscv-asm/generated/lib/info/lookup.rkt"
         "order-table.rkt")

(provide gas-rewrite
         gas-rewrite-program)

(define info-cache (make-hash))

(define (lookup-instruction target name)
  (define exts (target-extensions target))
  (hash-ref! info-cache (cons exts name)
             (lambda ()
               (and (pair? (instruction-info-candidates exts name))
                    (resolve-instruction-info exts name)))))

(define (rewrite-item target it)
  (cond
    [(and (form? it) (symbol? (car it)))
     (define-values (base _aq _rl) (split-aqrl (car it)))
     (define info (lookup-instruction target base))
     (define plan (and info (order-plan-of info)))
     (cond
       [(and plan (= (length (cdr it)) (order-plan-arity plan)))
        (cons (car it) (order-plan->native-operands plan (cdr it)))]
       [else it])]
    [else it]))

(define (gas-rewrite target items)
  (for/list ([it (in-list (as-items items))])
    (rewrite-item target it)))

(define (gas-rewrite-program target program)
  (gas-rewrite target program))
