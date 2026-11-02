#lang racket
;;; loko-compatibility/flow.rkt
;;;
;;; Loko/ELF 扩展的流。这是唯一知道 loko-compatibility 与 amd64-elf 的 flow
;;; 模块; compiler/ 不依赖它们。
;;;
;;; 形态和 compiler/flow/flow.rkt 一样: 一条 flow 值 + 一组绑定它的函数。
;;; 这里的 flow 是 (extend-flow core-flow …), 只多出自己的层和层组。

(require (prefix-in core: "../compiler/flow/core.rkt")
         (only-in "../compiler/expand-pseudo/rewrite.rkt"
                  rewrite-program pseudo-leftover?)
         (only-in "translate.rkt" translate-loko-source)
         (only-in "ir.rkt" make-loko-ir ir-list)
         (only-in "lower/ir.rkt" lower-loko-ir)
         (only-in "image/layout-spec.rkt" build-layout-spec)
         (only-in "image/plan.rkt" choose-loko-linux-image-plan)
         (only-in "../amd64-elf/writer.rkt" write-elf))

(provide (struct-out core:stage)
         stage-table
         stage-groups
         default-flow
         stage-names
         providers-of
         group-names
         select-stages
         run-flow
         run-stage
         compile
         compile-image
         flow-value)

(define loko-stage-table
  (hash
   'loko-compat
   (core:stage 'loko-compat '(loko-source)
               ;; aliases 已经内联进 items, 不再往流里传(它只是 translate 的中间表)
               '(program-items data-items loko-ir)
               (lambda (_target in)
                 (define out (translate-loko-source (hash-ref in 'loko-source)))
                 (define fields (cdr out))
                 (define problems (cdr (assq 'problems fields)))
                 (when (pair? problems)
                   (error 'loko-compat "~e" problems))
                 (hash 'program-items (cdr (assq 'program-items fields))
                       'data-items (cdr (assq 'data-items fields))
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

;; 只属于 loko-near 的层: expand-pseudo 的 near 版本(所有分支直接取 near,
;; 布局一次即可, 不跑 relax)。它是这条验证流的策略, 所以放在这里而不是 core。
(define expand-pseudo-near-stage
  (core:stage 'expand-pseudo-near '(program-items) '(program-items)
              (lambda (_target in)
                (define items
                  (rewrite-program (hash-ref in 'program-items)
                                   #:short-transfers? #f))
                (when (pseudo-leftover? items)
                  (error 'expand-pseudo-near
                         "pseudo instruction survived expansion: ~e" items))
                (hash 'program-items items))
              "伪指令 -> 真指令（全部 near，用于快速验证；布局一次即可）"))

(define loko-flow
  (core:extend-flow
   core:core-flow 'loko
   (hash-set loko-stage-table 'expand-pseudo-near expand-pseudo-near-stage)
   (hash
    'loko '(loko-compat loko-lower loko-image
                        expand-pseudo analyze dce relax
                        bind-labels encode)
    'loko-manual '(loko-compat loko-lower
                              expand-pseudo analyze dce relax
                              bind-labels encode)
    ;; near 验证流: 全 near + 只 layout 一次(不跑 relax)
    'loko-near '(loko-compat loko-lower loko-image
                             expand-pseudo-near analyze dce layout
                             bind-labels encode)
    'elf '(loko-compat loko-lower loko-image
                       expand-pseudo analyze dce relax
                       bind-labels encode loko-elf)
    'elf-manual '(loko-compat loko-lower
                             expand-pseudo analyze dce relax
                             bind-labels encode loko-elf))))

(define stage-table (core:flow-stages loko-flow))
(define stage-groups (core:flow-groups loko-flow))
(define default-flow (core:flow-default loko-flow))

(define (stage-names) (core:stage-names loko-flow))
(define (providers-of value) (core:providers-of loko-flow value))
(define (group-names) (core:group-names loko-flow))
(define (select-stages selector) (core:select-stages loko-flow selector))
(define (run-flow target selector [seeds '()])
  (core:run-flow loko-flow target selector seeds))
(define (run-stage target name [seeds '()])
  (core:run-stage loko-flow target name seeds))
(define (compile target seeds [selector #f])
  (core:compile loko-flow target seeds selector))
(define (compile-image target seeds [selector 'elf])
  (core:compile-image loko-flow target seeds selector))
(define flow-value core:flow-value)
