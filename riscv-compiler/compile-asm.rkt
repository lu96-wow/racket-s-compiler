#lang racket/base

;; ============================================================
;; 底层主链
;;
;; 两条入口：
;;   1. 纯 vreg asm（原有路径）
;;        asm -> CFG -> branch-opt -> CFG -> liveness
;;            -> interference -> coloring -> layout
;;
;;   2. frame / env / cont / call 形式（新路径）
;;        asm
;;          -> lower-frame-forms   (prologue + env-ref/env-set -> ld/sd)
;;          -> CFG -> branch-opt -> CFG
;;          -> liveness -> interference -> coloring
;;          -> lower-calls         (call/tailcall/return -> 真实指令 + epilogue)
;;          -> CFG -> branch-opt
;;          -> layout
;; ============================================================

(require racket/list
         "asm.rkt"
         "frame.rkt"
         "repr.rkt"
         "lower-frame.rkt"
         "literal-lower.rkt"
         "call-lower.rkt"
         "cfg.rkt"
         "branch-opt.rkt"
         "liveness.rkt"
         "interference.rkt"
         "regalloc-graph.rkt"
         "layout.rkt"
         "program.rkt")

(provide compile-asm
         compile-basic-asm
         compile-func-asm
         extended-asm?
         asm-items
         asm-name)

(define (asm-items source)
  (cond
    [(and (list? source)
          (pair? source)
          (eq? (car source) 'asm))
     (cdr source)]
    [(list? source) source]
    [else
     (error 'asm-items "expected (asm ...), got: ~a" source)]))

(define (asm-name asm)
  (define label-item (findf label? asm))
  (if label-item
      (cadr label-item)
      'main))

(define (extended-asm? asm)
  (for/or ([item (in-list asm)])
    (or (frame-form? item)
        (cont-form? item)
        (env-ref? item)
        (env-set? item)
        (call-form? item)
        (tailcall-form? item)
        (return-form? item)
        (struct-form? item))))

;; ------------------------------------------------------------
;; 原有路径：纯 vreg asm
;; ------------------------------------------------------------

(define (compile-basic-asm asm0)
  (define name (asm-name asm0))

  (define cfg0 (build-cfg asm0))
  (define asm1 (optimize-branches cfg0))

  (define cfg1 (build-cfg asm1))
  (define live (compute-liveness cfg1))
  (define interference (build-interference cfg1 live))

  (define-values (phys-asm regmap coloring)
    (allocate-registers-graph asm1 interference))

  (define-values (labels resolved)
    (layout phys-asm))

  (values name
          (make-program-sexpr name labels resolved)
          asm1
          cfg1
          live
          interference
          regmap
          coloring
          labels
          resolved))

;; ------------------------------------------------------------
;; 新路径：frame / env / cont / call 形式
;; ------------------------------------------------------------

(define (compile-func-asm asm0)
  (define name (asm-name asm0))

  ;; frame 声明 / cont 声明被抽走；env-ref/env-set 变成 ld/sd；
  ;; prologue 插在入口 label 之后。
  (define-values (asm-frame frame conts structs)
    (lower-frame-forms asm0))

  (define cfg0 (build-cfg asm-frame))
  (define asm1 (optimize-branches cfg0))

  (define cfg1 (build-cfg asm1))
  (define live (compute-liveness cfg1))
  (define interference (build-interference cfg1 live))

  (define-values (phys-asm regmap coloring)
    (allocate-registers-graph asm1 interference))

  ;; 参数移动、jal/jalr、epilogue。
  (define asm2 (lower-calls phys-asm frame conts))
  (define asm3 (optimize-branches (build-cfg asm2)))

  (define-values (labels resolved)
    (layout asm3))

  (values name
          (make-program-sexpr name labels resolved)
          asm1
          cfg1
          live
          interference
          regmap
          coloring
          labels
          resolved))

;; ------------------------------------------------------------
;; 入口
;; ------------------------------------------------------------

(define (compile-asm source)
  ;; const 是纯语法糖，先物化成 addi，不进入 CFG/liveness。
  (define asm0 (lower-literals (asm-items source)))
  (if (extended-asm? asm0)
      (compile-func-asm asm0)
      (compile-basic-asm asm0)))
