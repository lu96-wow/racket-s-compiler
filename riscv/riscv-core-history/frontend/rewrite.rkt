#lang racket
;;; frontend/rewrite.rkt
;;;
;;; 第三步：只改名字，不改代码语义。
;;;
;;; 输入：link 出来的 linked。
;;; 输出：resolved program —— 顶层只剩 func / data / raw，
;;;       所有 (global chain) 和 raw 里的全局 label 都是完整链。
;;;
;;; 这一层只关心：
;;;   - 把本地链替换成完整链；
;;;   - 保持 block / term / vreg / 指令形状不变。
;;;
;;; 它不关心：vreg 是否已声明、CFG 是否合法、指令如何降低。

(require "sexp.rkt"
         "program.rkt")

(provide rewrite-program)

(define (rewrite-program linked)
  (define prog (linked-program linked))
  (for/list ([u (in-list (reverse (program-units prog)))])
    (rewrite-unit prog linked u)))

(define (rewrite-unit prog linked u)
  (define module-name (unit-module u))
  (define imports (hash-ref (linked-imports linked) module-name '()))
  (define item (unit-item u))
  (define global (unit-global u))

  (cond
    [(func-form? item)
     (match item
       [(list 'func _local body ...)
        (cons 'func
              (cons global
                    (for/list ([form (in-list body)])
                      (rewrite-globals prog module-name imports form))))]
       [_ (error 'rewrite "internal: malformed func: ~e" item)])]

    ;; data body 里的 label 和 (global chain) 都要解析。
    [(data-form? item)
     (match item
       [(list 'data _local body ...)
        (cons 'data
              (cons global
                    (for/list ([form (in-list body)])
                      (rewrite-data-item prog module-name imports form))))]
       [_ (error 'rewrite "internal: malformed data: ~e" item)])]

    [(raw-form? item)
     (match item
       [(list 'raw _local body ...)
        (cons 'raw
              (cons global
                    (for/list ([form (in-list body)])
                      (rewrite-raw-item prog module-name imports form))))]
       [_ (error 'rewrite "internal: malformed raw: ~e" item)])]

    [else
     (error 'rewrite "internal: unexpected top-level item: ~e" item)]))

;; ---------------------------------------------------------------------------
;; func：只替换显式的 (global chain)。asm.code 是封闭 machine 块，原样保留。
;; ---------------------------------------------------------------------------

(define (rewrite-globals prog module-name imports form)
  (cond
    [(and (form? form) (eq? (car form) 'global))
     (match form
       [(list 'global (? chain? chain))
        (define full
          (resolve-local (program-defs prog) module-name imports chain))
        (unless full
          (error 'rewrite
                 "undefined global ~a in module ~a"
                 (chain->string chain)
                 (chain->string module-name)))
        (list 'global full)]
       [_ (error 'rewrite "malformed global reference: ~e" form)])]

    ;; inline asm 是封闭的：不改它内部的名字。
    [(and (form? form) (eq? (car form) 'asm))
     form]

    [(list? form)
     (for/list ([x (in-list form)])
       (rewrite-globals prog module-name imports x))]

    [else form]))

;; ---------------------------------------------------------------------------
;; data：label 定义和 (global chain) 都是全局名。
;; ---------------------------------------------------------------------------

(define (rewrite-data-item prog module-name imports form)
  (cond
    [(and (form? form) (eq? (car form) 'label))
     (match form
       [(list 'label chains ...)
        (when (null? chains)
          (error 'rewrite "data label needs one or more name chains: ~e" form))
        (cons 'label
              (for/list ([chain (in-list chains)])
                (unless (chain? chain)
                  (error 'rewrite "data label must be a name chain: ~e" chain))
                (define full (append module-name chain))
                (unless (hash-has-key? (program-defs prog) full)
                  (error 'rewrite
                         "data label ~a is not defined in module ~a"
                         (chain->string chain)
                         (chain->string module-name)))
                full))]
       [_ (error 'rewrite "malformed data label: ~e" form)])]

    [else (rewrite-globals prog module-name imports form)]))

;; ---------------------------------------------------------------------------
;; raw：label 定义和 native 控制转移目标是全局名。
;; 其它原生指令原样保留；这一层不解释编码。
;; ---------------------------------------------------------------------------

(define (rewrite-raw-item prog module-name imports form)
  (cond
    [(and (form? form) (eq? (car form) 'label))
     (rewrite-raw-label prog module-name form)]

    [else
     (define index
       (and (form? form) (raw-label-operand-index (car form))))
     (cond
       [index
        (rewrite-raw-target prog module-name imports form index)]
       [else form])]))

(define (rewrite-raw-label prog module-name form)
  (match form
    [(list 'label chains ...)
     (when (null? chains)
       (error 'rewrite "raw label needs one or more name chains: ~e" form))
     (cons 'label
           (for/list ([chain (in-list chains)])
             (unless (chain? chain)
               (error 'rewrite "raw label must be a name chain: ~e" chain))
             (define full (append module-name chain))
             (unless (hash-has-key? (program-defs prog) full)
               (error 'rewrite
                      "raw label ~a is not defined in module ~a"
                      (chain->string chain)
                      (chain->string module-name)))
             full))]
    [_ (error 'rewrite "malformed raw label: ~e" form)]))

(define (rewrite-raw-target prog module-name imports form index)
  (define operands (cdr form))
  (when (<= (length operands) index)
    (error 'rewrite
           "~a is missing its label operand: ~e"
           (car form) form))
  (define target (list-ref operands index))
  (unless (chain? target)
    (error 'rewrite
           "~a target must be a name chain: ~e"
           (car form) target))
  (define full
    (resolve-local (program-defs prog) module-name imports target))
  (unless full
    (error 'rewrite
           "undefined raw label ~a in module ~a"
           (chain->string target)
           (chain->string module-name)))
  (cons (car form)
        (append (take operands index)
                (list full)
                (drop operands (add1 index)))))
