#lang racket
;;; encode/syntax/coverage.rkt
;;;
;;; 覆盖检查。
;;;
;;; native 是基础语法: 每个 instruction-info 都有 native plan。
(require "../../../riscv-asm/generated/lib/info/lookup.rkt"
         "../../../riscv-asm/generated/lib/info/struct.rkt"
         "plan.rkt")

(provide missing-native-syntax
         syntax-coverage)

;; native 理论上不该缺；保留这个检查，防止以后 native plan 被改坏。
(define (missing-native-syntax [extensions (instruction-info-extensions)])
  (append*
   (for/list ([e (in-list extensions)])
     (for/list ([i (in-list (extension-instruction-info e))]
                #:unless (syntax-plan-for i))
       (list e (instruction-info-name i) (instruction-info-operands i))))))

(define (syntax-coverage [extensions (instruction-info-extensions)])
  (define infos
    (append* (for/list ([e (in-list extensions)])
               (extension-instruction-info e))))
  (define native-missing (missing-native-syntax extensions))
  (hash 'extensions (length extensions)
        'instructions (length infos)
        'native-missing (length native-missing)))
