#lang racket
;;; encode/syntax/coverage.rkt
;;;
;;; 覆盖检查: 哪些 instruction-info 还没有 syntax-plan。
;;;
;;; 这是扩展"所有 RISC-V 扩展"时的工作清单来源:
;;; 不靠手写表猜, 直接从 riscv-asm 的 metadata 生成缺项列表。

(require "../../../riscv-asm/generated/lib/info/lookup.rkt"
         "../../../riscv-asm/generated/lib/info/struct.rkt"
         "plan.rkt")

(provide missing-syntax
         syntax-coverage)

;; -> ((扩展 指令名 operands) ...)
(define (missing-syntax [extensions (instruction-info-extensions)])
  (append*
   (for/list ([e (in-list extensions)])
     (for/list ([i (in-list (extension-instruction-info e))]
                #:unless (syntax-plan-for i))
       (list e (instruction-info-name i) (instruction-info-operands i))))))

;; 汇总给工具/测试看。
(define (syntax-coverage [extensions (instruction-info-extensions)])
  (define infos
    (append* (for/list ([e (in-list extensions)])
               (extension-instruction-info e))))
  (define missing (missing-syntax extensions))
  (hash 'extensions (length extensions)
        'instructions (length infos)
        'covered (- (length infos) (length missing))
        'missing (length missing)
        'missing-rows missing))
