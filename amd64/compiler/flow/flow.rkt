#lang racket
;;; amd64/compiler/flow/flow.rkt
;;;
;;; 核心流的公开入口: 把 `core-flow` 绑进引擎的那组函数。
;;; 需要额外阶段的前端用各自的 extend-flow 入口（形状相同）。
;;;
;;;   (compile target seeds)                    ; 默认流 -> build
;;;   (run-flow target 'backend seeds)          ; 层组
;;;   (run-flow target '(dce layout) seeds)     ; 任意片段

(require (prefix-in core: "core.rkt"))

(provide (struct-out core:stage)
         stage-table
         default-flow
         stage-names
         providers-of
         select-stages
         group-names
         run-flow
         run-stage
         compile
         compile-image
         flow-value)

(define stage-table (core:flow-stages core:core-flow))
(define default-flow (core:flow-default core:core-flow))

(define (stage-names) (core:stage-names core:core-flow))
(define (providers-of value) (core:providers-of core:core-flow value))
(define (select-stages selector) (core:select-stages core:core-flow selector))
(define (group-names) (core:group-names core:core-flow))
(define (run-flow target selector [seeds '()])
  (core:run-flow core:core-flow target selector seeds))
(define (run-stage target name [seeds '()])
  (core:run-stage core:core-flow target name seeds))
(define (compile target seeds [selector #f])
  (core:compile core:core-flow target seeds selector))
(define (compile-image target seeds [selector #f])
  (core:compile-image core:core-flow target seeds selector))
(define flow-value core:flow-value)
