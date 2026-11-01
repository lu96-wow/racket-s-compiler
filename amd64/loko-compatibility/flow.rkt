#lang racket
;;; loko-compatibility/flow.rkt
;;;
;;; Optional Loko/ELF extension of the core assembly flow.  This is the only
;;; flow module that knows about loko-compatibility and amd64-elf; compiler/
;;; remains usable without either of them.

(require (prefix-in core: "../compiler/flow/core.rkt")
         (only-in "translate.rkt" translate-loko-source)
         (only-in "ir.rkt" make-loko-ir ir-list)
         (only-in "lower/ir.rkt" lower-loko-ir)
         (only-in "image/layout-spec.rkt" build-layout-spec)
         (only-in "image/plan.rkt" choose-loko-linux-image-plan)
         (only-in "../amd64-elf/writer.rkt" write-elf))

(provide (struct-out core:stage)
         stage-table
         stage-names
         providers-of
         stage-groups
         group-names
         select-stages
         run-flow
         run-stage
         compile
         compile-image
         context-value
         default-flow)

(define loko-stage-table
  (hash
   'loko-compat
   (core:stage 'loko-compat '(loko-source)
               '(program-items data-items loko-aliases loko-ir)
               (lambda (_target in)
                 (define out (translate-loko-source (hash-ref in 'loko-source)))
                 (define fields (cdr out))
                 (define problems (cdr (assq 'problems fields)))
                 (when (pair? problems)
                   (error 'loko-compat "~e" problems))
                 (hash 'program-items (cdr (assq 'program-items fields))
                       'data-items (cdr (assq 'data-items fields))
                       'loko-aliases (cdr (assq 'aliases fields))
                       'loko-ir (make-loko-ir
                                 (cadr (assq 'origin fields))
                                 (cdr (assq 'symbols fields))
                                 (cdr (assq 'comms fields))
                                 (cdr (assq 'sections fields))
                                 (cdr (assq 'image-plan fields)))))
               "Loko 汇编写法 -> 核心 item + loko-ir")

   'loko-lower
   (core:stage 'loko-lower '(loko-ir) '(loko-ir)
               (lambda (_target in)
                 (define-values (ir problems)
                   (lower-loko-ir (hash-ref in 'loko-ir)))
                 (when (pair? problems)
                   (error 'loko-lower "~e" problems))
                 (hash 'loko-ir ir))
               "loko-ir: code section 的 (reg N) -> 物理寄存器")

   'loko-image
   (core:stage 'loko-image '(loko-ir)
               '(program-items data-items layout-spec)
               (lambda (_target in)
                 ;; 先把 %elf 计划定下来: 地址在这一步之后的 layout 里求解,
                 ;; 所以"页/权限边界"这类约束必须现在就交给 layout-spec。
                 ;; 和 loko-elf 用同一个纯函数, 两边结果一致。
                 (define ir (hash-ref in 'loko-ir))
                 (define plan (choose-loko-linux-image-plan
                               (ir-list ir 'symbols)
                               (ir-list ir 'image-plan)))
                 (define-values (spec program-items data-items problems)
                   (build-layout-spec ir plan))
                 (when (pair? problems)
                   (error 'loko-image "~e" problems))
                 (hash 'program-items program-items
                       'data-items data-items
                       'layout-spec spec))
               "loko-ir -> layout-spec + 扁平 items")

   'loko-elf
   (core:stage 'loko-elf '(build bound-layout loko-ir) '(image)
               (lambda (_target in)
                 (define symbols
                   (cdr (assq 'symbols (hash-ref in 'bound-layout))))
                 (define plan
                   (choose-loko-linux-image-plan
                    symbols
                    (ir-list (hash-ref in 'loko-ir) 'image-plan)))
                 (hash 'image
                       (write-elf (hash-ref in 'build) symbols #:plan plan)))
               "build + symbols + image-plan -> ELF64 image")))

(define stage-table
  (make-immutable-hash
   (append (hash->list core:core-stage-table)
           (hash->list loko-stage-table))))

(define stage-groups
  (make-immutable-hash
   (append (hash->list core:core-stage-groups)
           (hash->list
            (hash
             'loko '(loko-compat loko-lower loko-image
                                 expand-pseudo analyze dce relax
                                 bind-labels encode)
             'loko-manual '(loko-compat loko-lower
                                       expand-pseudo analyze dce relax
                                       bind-labels encode)
             'loko-near '(loko-compat loko-lower loko-image
                                     expand-pseudo-near analyze dce layout
                                     bind-labels encode)
             'elf '(loko-compat loko-lower loko-image
                                expand-pseudo analyze dce relax
                                bind-labels encode loko-elf)
             'elf-manual '(loko-compat loko-lower
                                      expand-pseudo analyze dce relax
                                      bind-labels encode loko-elf))))))

(define default-flow core:default-flow)

(for ([(g stages) (in-hash stage-groups)])
  (when (hash-has-key? stage-table g)
    (error 'flow "stage group ~a conflicts with a stage name" g))
  (unless (and (list? stages)
               (andmap symbol? stages)
               (andmap (lambda (s) (hash-has-key? stage-table s)) stages))
    (error 'flow "bad stage group ~a: ~e" g stages)))

(define (stage-names)
  (core:stage-names #:stage-table stage-table))

(define (providers-of value)
  (core:providers-of value #:stage-table stage-table))

(define (group-names)
  (core:group-names #:stage-groups stage-groups))

(define (select-stages selector)
  (core:select-stages selector
                      #:stage-table stage-table
                      #:stage-groups stage-groups))

(define (run-flow target selector [seeds '()])
  (core:run-flow target selector seeds
                 #:stage-table stage-table
                 #:stage-groups stage-groups))

(define (run-stage target name [seeds '()])
  (core:run-stage target name seeds
                  #:stage-table stage-table
                  #:stage-groups stage-groups))

(define (compile target seeds [flow default-flow])
  (core:compile target seeds flow
                #:stage-table stage-table
                #:stage-groups stage-groups))

(define (compile-image target seeds [flow 'elf])
  (core:compile-image target seeds flow
                      #:stage-table stage-table
                      #:stage-groups stage-groups))

(define context-value core:context-value)
