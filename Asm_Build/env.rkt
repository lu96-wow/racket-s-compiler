#lang racket

(require "asm.rkt"
         racket/match
         racket/set)

(provide env-let-reg env-let-reg?
         env-let-reg-bindings env-let-reg-body
         resolve-env
         register-pool)

;; ============================================================
;; AST
;; ============================================================

(struct env-let-reg (bindings body) #:transparent)
;; bindings: (listof (cons/c symbol (or/c 'get-reg symbol?)))
;;   spec='get-reg → 自动分配; spec=寄存器名 → 显式绑定
;; body:     (listof asm-item) — 可嵌套 env-let-reg

;; ============================================================
;; 物理寄存器池（符号）
;; ============================================================

(define register-pool
  (for/list ([i (in-range 1 32)])
    (string->symbol (format "x~a" i))))  ;; x1-x31

;; ============================================================
;; get-reg 占位：从池中选第一个空闲寄存器
;; ============================================================

(define (get-reg used)
  ;; used: (setof symbol) — 当前占用的寄存器符号
  (for/or ([r (in-list register-pool)])
    (and (not (set-member? used r)) r)))

;; ============================================================
;; env 消解：展开 let-reg，替换虚拟名 → 物理寄存器符号
;; ============================================================

(define (resolve-env items)
  (resolve-env/frame items '() (set)))

;; frames: (listof (hash/c symbol symbol))，内层在前
;; used:   (setof symbol) 所有已占用的寄存器
(define (resolve-env/frame items frames used)
  (define out '())
  (for ([item (in-list items)])
    (match item
      ;; let-reg → 分配寄存器，递归处理 body
      [(env-let-reg bindings body)
       (define new-frame (make-hash))
       (define new-used used)
       (for ([b (in-list bindings)])
         (match-define (cons name spec) b)
         (define r
           (cond
             [(eq? spec 'get-reg)
              (get-reg new-used)]
             [(symbol? spec)
              (when (set-member? new-used spec)
                (error 'env "register ~a already in use" spec))
              spec]
             [else (error 'env "invalid binding spec: ~a" spec)]))
         (unless r (error 'env "out of registers in let-reg"))
         (hash-set! new-frame name r)
         (set! new-used (set-add new-used r)))
       (define resolved-body
         (resolve-env/frame body (cons new-frame frames) new-used))
       (set! out (append out resolved-body))]
      ;; 指令 → 替换参数中的虚拟名
      [(asm-insn mnemonic args)
       (define resolved-args
         (for/list ([arg (in-list args)])
           (lookup-reg arg frames)))
       (set! out (cons (asm-insn mnemonic resolved-args) out))]
      ;; label / space → 原样
      [_ (set! out (cons item out))]))
  (reverse out))

;; 在帧链中查找符号 → 物理寄存器符号
(define (lookup-reg sym frames)
  (cond
    [(exact-integer? sym) sym]
    [(reg-num sym) sym]               ;; 已经是寄存器 → 保持
    [else
     (let loop ([fs frames])
       (cond
         [(null? fs) sym]              ;; 不在任何帧中 → label 引用
         [(hash-ref (car fs) sym #f)]
         [else (loop (cdr fs))]))]))
