#lang racket/base

;; ============================================================
;; mini Scheme core -> F-asm
;;
;; 支持：
;;   字面量 / 变量 / quote / if / lambda / let / letrec / set! / begin
;;   应用 / call/cc
;;   基本 primitive：+ - * / mod = < <= > >=
;;   cons car cdr null? pair? procedure? eq? box unbox set-box!
;;   display newline
;;
;; 约定：
;;   - 参数/返回值只通过 value vector：pack / arg-ref
;;   - 不使用真实寄存器（a0..a7 等）
;;   - 当前 continuation 在 k 寄存器
;;   - frame 由 callee 自己 alloc，link = closure.env
;;   - 非尾调用显式 (cont k Lret) + (call ...)
;;   - 尾调用 (tailcall ...)，不分配 continuation
;; ============================================================

(require racket/list
         racket/string
         "fasm.rkt")

(provide compile-scheme)

;; ------------------------------------------------------------
;; frame / env
;; ------------------------------------------------------------

(struct frame (vars next vreg-slots) #:mutable)

(define (frame-copy f)
  (frame (append (frame-vars f) '())
         (frame-next f)
         (make-hash)))

(define (frame-add! f name)
  (define idx (frame-next f))
  ;; vars 存 (name . slot)，因为 temp slot 可能插在变量之间。
  (set-frame-vars! f (append (frame-vars f) (list (cons name idx))))
  (set-frame-next! f (add1 idx))
  idx)

;; 给跨调用的临时 vreg 分配一个 frame slot。
(define (vreg-slot! f vreg frame-max)
  (or (hash-ref (frame-vreg-slots f) vreg #f)
      (let ([idx (frame-next f)])
        (set-frame-next! f (add1 idx))
        (hash-set! (frame-vreg-slots f) vreg idx)
        (set-box! frame-max (max (unbox frame-max) (frame-next f)))
        idx)))

;; env 是 frame 列表，head = 当前 frame。
(define (env-lookup env name)
  (let loop ([frames env] [depth 0])
    (cond
      [(null? frames) #f]
      [else
       (define entry (assoc name (frame-vars (car frames))))
       (if entry
           (list depth (cdr entry))
           (loop (cdr frames) (add1 depth)))])))

;; ------------------------------------------------------------
;; 编译状态
;; ------------------------------------------------------------

(struct cstate (vregs labels pending current-vregs defined) #:mutable)

(define (fresh-vreg! st)
  (define n (cstate-vregs st))
  (set-cstate-vregs! st (add1 n))
  (define v (string->symbol (format "v~a" n)))
  (set-cstate-current-vregs! st (cons v (cstate-current-vregs st)))
  v)

(define (fresh-label! st)
  (define n (cstate-labels st))
  (set-cstate-labels! st (add1 n))
  (string->symbol (format "L~a" n)))

(define (add-pending! st code)
  (set-cstate-pending! st (append (cstate-pending st) (list code))))

;; ------------------------------------------------------------
;; primitive 表
;; ------------------------------------------------------------

(define primitive-arities
  '((+ . 2) (- . 2) (* . 2) (/ . 2) (mod . 2)
    (= . 2) (< . 2) (<= . 2) (> . 2) (>= . 2)
    (cons . 2) (car . 1) (cdr . 1)
    (null? . 1) (pair? . 1) (procedure? . 1)
    (fixnum? . 1) (boolean? . 1) (symbol? . 1) (string? . 1)
    (vector? . 1) (box? . 1)
    (eq? . 2) (box . 1) (unbox . 1) (set-box! . 2)
    (display . 1) (newline . 0)))

(define (primitive-name? name)
  (and (assoc name primitive-arities) #t))

(define (primitive-arity name)
  (cdr (assoc name primitive-arities)))

(define (prim-name name)
  (case name
    [(+) 'add]
    [(-) 'sub]
    [(*) 'mul]
    [(/) 'div]
    [(=) 'eq?]
    [(<) 'lt]
    [(<=) 'le]
    [(>) 'gt]
    [(>=) 'ge]
    [else name]))

(define (no-value-primitive? name)
  (memq name '(display newline)))

;; ------------------------------------------------------------
;; 工具
;; ------------------------------------------------------------

(define (body->expr body)
  (cond
    [(null? body) 'nil]
    [(null? (cdr body)) (car body)]
    [else (cons 'begin body)]))

(define (check-arity who args expected)
  (unless (= (length args) expected)
    (error who "expected ~a arguments, got ~a" expected (length args))))

(define (compile-variable name dst env)
  (define loc (env-lookup env name))
  (unless loc
    (error 'scheme-core "unbound variable: ~a" name))
  (list (list 'env-ref dst (list 'env (car loc) (cadr loc)))))

;; ------------------------------------------------------------
;; quote
;; ------------------------------------------------------------

(define (compile-quote datum dst st)
  (cond
    [(or (null? datum) (eq? datum 'nil))
     (list (list 'const dst 'nil))]
    [(symbol? datum)
     (list (list 'const dst (list 'quote datum)))]
    [(or (exact-integer? datum) (boolean? datum) (char? datum) (string? datum))
     (list (list 'const dst datum))]
    [(pair? datum)
     (define car-v (fresh-vreg! st))
     (define cdr-v (fresh-vreg! st))
     (append
      (compile-quote (car datum) car-v st)
      (compile-quote (cdr datum) cdr-v st)
      (list (list 'prim 'cons dst car-v cdr-v)))]
    [else
     (error 'scheme-core "unsupported quoted datum: ~a" datum)]))

;; ------------------------------------------------------------
;; lambda
;; ------------------------------------------------------------

(define (compile-lambda expr dst env frame-max st)
  (define params (cadr expr))
  (define body (cddr expr))
  (unless (andmap symbol? params)
    (error 'scheme-core "lambda params must be symbols: ~a" params))

  (define label (fresh-label! st))
  (define arity (length params))

  ;; 当前 frame 在 lambda 定义点被 snapshot；之后新增的 let 变量不可见。
  (define outer-env
    (cons (frame-copy (car env)) (cdr env)))
  (define params-frame
    (frame (for/list ([p (in-list params)] [i (in-naturals)]) (cons p i))
           arity
           (make-hash)))
  (define new-env (cons params-frame outer-env))
  (define new-frame-max (box arity))

  ;; lambda body 有自己的一组 vregs / defined 集合。
  (define saved-vregs (cstate-current-vregs st))
  (define saved-defined (cstate-defined st))
  (set-cstate-current-vregs! st '())
  (set-cstate-defined! st (make-hash))
  (define param-stores
    (for/list ([_ (in-list params)]
               [i (in-naturals)])
      (define tmp (fresh-vreg! st))
      (list (list 'arg-ref tmp i)
            (list 'env-set (list 'env 0 i) tmp))))
  (define body-code
    (compile-tail (body->expr body) new-env new-frame-max st))
  (set-cstate-current-vregs! st saved-vregs)
  (set-cstate-defined! st saved-defined)

  (define frame-size (unbox new-frame-max))

  (add-pending!
   st
   (append
    (list (list 'label label)
          (list 'alloc-frame frame-size))
    (append* param-stores)
    body-code))

  (list (list 'closure dst label arity)))

;; ------------------------------------------------------------
;; let / letrec
;; ------------------------------------------------------------

(define (compile-let expr dst env frame-max st tail?)
  (define bindings (cadr expr))
  (define body (cddr expr))
  (define current (car env))
  (define saved-vars (frame-vars current))

  ;; 先算 initializer；此时新变量还不在作用域里。
  (define temps (for/list ([_ (in-list bindings)]) (fresh-vreg! st)))
  (define init-code
    (append*
     (for/list ([binding (in-list bindings)]
                [tmp (in-list temps)])
       (compile-value (cadr binding) tmp env frame-max st))))

  (define indices
    (for/list ([binding (in-list bindings)])
      (define idx (frame-add! current (car binding)))
      (set-box! frame-max (max (unbox frame-max) (frame-next current)))
      idx))

  (define store-code
    (for/list ([idx (in-list indices)]
               [tmp (in-list temps)])
      (list 'env-set (list 'env 0 idx) tmp)))

  (define body-code
    (if tail?
        (compile-tail (body->expr body) env frame-max st)
        (compile-value (body->expr body) dst env frame-max st)))

  (set-frame-vars! current saved-vars)

  (append init-code store-code body-code))

(define (compile-letrec expr dst env frame-max st tail?)
  (define bindings (cadr expr))
  (define body (cddr expr))
  (define current (car env))
  (define saved-vars (frame-vars current))

  ;; 先把所有变量加进作用域，RHS 的lambda才能递归引用。
  (define indices
    (for/list ([binding (in-list bindings)])
      (define idx (frame-add! current (car binding)))
      (set-box! frame-max (max (unbox frame-max) (frame-next current)))
      idx))

  ;; 初始化成 nil。
  (define nil-v (fresh-vreg! st))
  (define nil-code
    (append*
     (for/list ([idx (in-list indices)])
       (list (list 'const nil-v 'nil)
             (list 'env-set (list 'env 0 idx) nil-v)))))

  (define temps (for/list ([_ (in-list bindings)]) (fresh-vreg! st)))
  (define rhs-code
    (append*
     (for/list ([binding (in-list bindings)]
                [tmp (in-list temps)])
       (compile-value (cadr binding) tmp env frame-max st))))

  (define store-code
    (for/list ([idx (in-list indices)]
               [tmp (in-list temps)])
      (list 'env-set (list 'env 0 idx) tmp)))

  (define body-code
    (if tail?
        (compile-tail (body->expr body) env frame-max st)
        (compile-value (body->expr body) dst env frame-max st)))

  (set-frame-vars! current saved-vars)

  (append nil-code rhs-code store-code body-code))

;; ------------------------------------------------------------
;; primitive / application
;; ------------------------------------------------------------

(define (compile-args args env frame-max st)
  (define regs (for/list ([_ (in-list args)]) (fresh-vreg! st)))
  (values regs
          (append*
           (for/list ([arg (in-list args)]
                      [reg (in-list regs)])
             (compile-value arg reg env frame-max st)))))

(define (compile-primitive-value op args dst env frame-max st)
  (check-arity op args (primitive-arity op))
  (define-values (arg-regs arg-code)
    (compile-args args env frame-max st))
  (append
   arg-code
   (cond
     [(no-value-primitive? op)
      (append
       (if (eq? op 'display)
           (list (list 'prim 'display (car arg-regs)))
           (list (list 'prim 'newline)))
       (list (list 'const dst 'nil)))]
     [else
      (list (apply list 'prim (prim-name op) dst arg-regs))])))

(define (tail-return-code code vreg)
  (append code
          (list (list 'pack 'vals vreg)
                (list 'return 'vals))))

(define (compile-primitive-tail op args env frame-max st)
  (check-arity op args (primitive-arity op))
  (define-values (arg-regs arg-code)
    (compile-args args env frame-max st))
  (cond
    [(no-value-primitive? op)
     (define tmp (fresh-vreg! st))
     (tail-return-code
      (append
       arg-code
       (if (eq? op 'display)
           (list (list 'prim 'display (car arg-regs)))
           (list (list 'prim 'newline)))
       (list (list 'const tmp 'nil)))
      tmp)]
    [else
     (define tmp (fresh-vreg! st))
     (tail-return-code
      (append arg-code
              (list (apply list 'prim (prim-name op) tmp arg-regs)))
      tmp)]))

(define (compile-application-value expr dst env frame-max st)
  (define op (car expr))
  (define args (cdr expr))
  (define fv (fresh-vreg! st))
  (define f-code (compile-value op fv env frame-max st))
  (define-values (arg-regs arg-code)
    (compile-args args env frame-max st))
  (define kret (fresh-label! st))
  (define argv-v (fresh-vreg! st))
  (define spill (spill-defined! env frame-max st))
  (define restore (restore-defined! env frame-max st))
  (append
   f-code
   arg-code
   spill
   (list (cons 'pack (cons argv-v arg-regs))
         (list 'cont 'k kret)
         (list 'call fv argv-v (list 'cont 'k))
         (list 'label kret))
   restore
   (list (list 'arg-ref dst 0))))

(define (compile-application-tail expr env frame-max st)
  (define op (car expr))
  (define args (cdr expr))
  (define fv (fresh-vreg! st))
  (define f-code (compile-value op fv env frame-max st))
  (define-values (arg-regs arg-code)
    (compile-args args env frame-max st))
  (define argv-v (fresh-vreg! st))
  (append
   f-code
   arg-code
   (list (cons 'pack (cons argv-v arg-regs))
         (list 'tailcall fv argv-v))))

;; ------------------------------------------------------------
;; call/cc
;; ------------------------------------------------------------

(define (compile-call/cc-value expr dst env frame-max st)
  (define args (cdr expr))
  (check-arity 'call/cc args 1)
  (define fv (fresh-vreg! st))
  (define f-code (compile-value (car args) fv env frame-max st))
  (define kret (fresh-label! st))
  (define spill (spill-defined! env frame-max st))
  (define restore (restore-defined! env frame-max st))
  (append
   f-code
   spill
   (list (list 'cont 'k kret)
         (list 'prim 'call/cc fv)
         (list 'label kret))
   restore
   (list (list 'arg-ref dst 0))))

(define (compile-call/cc-tail expr env frame-max st)
  (define args (cdr expr))
  (check-arity 'call/cc args 1)
  (define fv (fresh-vreg! st))
  (append
   (compile-value (car args) fv env frame-max st)
   (list (list 'prim 'call/cc fv))))

;; ------------------------------------------------------------
;; compile-value
;; ------------------------------------------------------------

(define (compile-value* expr dst env frame-max st)
  (cond
    [(or (null? expr) (eq? expr 'nil))
     (list (list 'const dst 'nil))]
    [(or (exact-integer? expr) (boolean? expr) (char? expr) (string? expr))
     (list (list 'const dst expr))]
    [(symbol? expr)
     (compile-variable expr dst env)]
    [(pair? expr)
     (case (car expr)
       [(quote)
        (compile-quote (cadr expr) dst st)]
       [(if)
        (define cond-v (fresh-vreg! st))
        (define Lelse (fresh-label! st))
        (define Lend (fresh-label! st))
        (define else-expr
          (if (null? (cdddr expr)) 'nil (cadddr expr)))
        (append
         (compile-value (cadr expr) cond-v env frame-max st)
         (list (list 'branch-if-not cond-v Lelse))
         (compile-value (caddr expr) dst env frame-max st)
         (list (list 'jump Lend)
               (list 'label Lelse))
         (compile-value else-expr dst env frame-max st)
         (list (list 'label Lend)))]
       [(lambda)
        (compile-lambda expr dst env frame-max st)]
       [(let)
        (compile-let expr dst env frame-max st #f)]
       [(letrec)
        (compile-letrec expr dst env frame-max st #f)]
       [(set!)
        (define name (cadr expr))
        (define loc (env-lookup env name))
        (unless loc (error 'scheme-core "set!: unbound variable: ~a" name))
        (define tmp (fresh-vreg! st))
        (append
         (compile-value (caddr expr) tmp env frame-max st)
         (list (list 'env-set (list 'env (car loc) (cadr loc)) tmp)
               (list 'const dst 'nil)))]
       [(begin)
        (define body (cdr expr))
        (cond
          [(null? body) (list (list 'const dst 'nil))]
          [else
           (define inits
             (for/list ([e (in-list (drop-right body 1))])
               (define tmp (fresh-vreg! st))
               (compile-value e tmp env frame-max st)))
           (append (append* inits)
                   (compile-value (last body) dst env frame-max st))])]
       [(call/cc)
        (compile-call/cc-value expr dst env frame-max st)]
       [else
        (cond
          [(primitive-name? (car expr))
           (compile-primitive-value (car expr) (cdr expr) dst env frame-max st)]
          [else
           (compile-application-value expr dst env frame-max st)])])]
    [else
     (error 'scheme-core "unsupported expression: ~a" expr)]))

;; 包装：一个表达式生成完，才把 dst 标记为 defined。
;; 这样嵌套调用 spill 时不会去读还没定义的 vreg。
(define (compile-value expr dst env frame-max st)
  (define code (compile-value* expr dst env frame-max st))
  (hash-set! (cstate-defined st) dst #t)
  code)

;; 调用前：把所有已定义 vreg 写回当前 frame。
;; 调用后：从当前 frame 恢复。
(define (spill-defined! env frame-max st)
  (define current (car env))
  (for/list ([v (in-list (sort (hash-keys (cstate-defined st)) symbol<?))])
    (define slot (vreg-slot! current v frame-max))
    (list 'env-set (list 'env 0 slot) v)))

(define (restore-defined! env frame-max st)
  (define current (car env))
  (for/list ([v (in-list (sort (hash-keys (cstate-defined st)) symbol<?))])
    (define slot (vreg-slot! current v frame-max))
    (list 'env-ref v (list 'env 0 slot))))

;; ------------------------------------------------------------
;; compile-tail
;; ------------------------------------------------------------

(define (compile-tail expr env frame-max st)
  (cond
    [(or (null? expr) (eq? expr 'nil))
     (define v (fresh-vreg! st))
     (tail-return-code (list (list 'const v 'nil)) v)]
    [(or (exact-integer? expr) (boolean? expr) (char? expr) (string? expr))
     (define v (fresh-vreg! st))
     (tail-return-code (list (list 'const v expr)) v)]
    [(symbol? expr)
     (define v (fresh-vreg! st))
     (tail-return-code (compile-variable expr v env) v)]
    [(pair? expr)
     (case (car expr)
       [(quote)
        (define v (fresh-vreg! st))
        (tail-return-code (compile-quote (cadr expr) v st) v)]
       [(if)
        (define cond-v (fresh-vreg! st))
        (define Lelse (fresh-label! st))
        (define Lend (fresh-label! st))
        (define else-expr
          (if (null? (cdddr expr)) 'nil (cadddr expr)))
        (append
         (compile-value (cadr expr) cond-v env frame-max st)
         (list (list 'branch-if-not cond-v Lelse))
         (compile-tail (caddr expr) env frame-max st)
         (list (list 'jump Lend)
               (list 'label Lelse))
         (compile-tail else-expr env frame-max st)
         (list (list 'label Lend)))]
       [(lambda)
        (define v (fresh-vreg! st))
        (tail-return-code (compile-lambda expr v env frame-max st) v)]
       [(let)
        (compile-let expr 'unused env frame-max st #t)]
       [(letrec)
        (compile-letrec expr 'unused env frame-max st #t)]
       [(set!)
        (define name (cadr expr))
        (define loc (env-lookup env name))
        (unless loc (error 'scheme-core "set!: unbound variable: ~a" name))
        (define tmp (fresh-vreg! st))
        (tail-return-code
         (append
          (compile-value (caddr expr) tmp env frame-max st)
          (list (list 'env-set (list 'env (car loc) (cadr loc)) tmp)
                (list 'const tmp 'nil)))
         tmp)]
       [(begin)
        (define body (cdr expr))
        (cond
          [(null? body)
           (define v (fresh-vreg! st))
           (tail-return-code (list (list 'const v 'nil)) v)]
          [else
           (define inits
             (for/list ([e (in-list (drop-right body 1))])
               (define tmp (fresh-vreg! st))
               (compile-value e tmp env frame-max st)))
           (append (append* inits)
                   (compile-tail (last body) env frame-max st))])]
       [(call/cc)
        (compile-call/cc-tail expr env frame-max st)]
       [else
        (cond
          [(primitive-name? (car expr))
           (compile-primitive-tail (car expr) (cdr expr) env frame-max st)]
          [else
           (compile-application-tail expr env frame-max st)])])]
    [else
     (error 'scheme-core "unsupported expression: ~a" expr)]))

;; ------------------------------------------------------------
;; 入口
;; ------------------------------------------------------------

(define (compile-scheme expr)
  (define st (cstate 0 0 '() '() (make-hash)))
  (define main-frame (frame '() 0 (make-hash)))
  (define frame-max (box 0))
  (define body (compile-tail expr (list main-frame) frame-max st))
  (define main-code
    (append
     (list (list 'label 'main)
           (list 'alloc-frame (unbox frame-max)))
     body))
  (define lambda-code (append* (cstate-pending st)))
  (cons 'fasm (append main-code lambda-code)))
