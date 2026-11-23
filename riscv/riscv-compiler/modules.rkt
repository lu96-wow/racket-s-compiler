#lang racket/base

;;; modules.rkt
;;;
;;; 共享的模块名解析引擎。
;;;
;;; label、struct、以及以后别的“模块作用域名字空间”都只提供三样东西：
;;;   * declarations: 完整链 -> 本地声明（只用来判断某个名字是否存在）
;;;   * own:          模块 -> 本模块直接声明了哪些本地链（给 provide * 用）
;;;   * extern:       外部模块 -> 已经解析好的 (外部链 . 绝对链) 导出表
;;;
;;; 本文件只负责模块树、provide/require、prefix-in/rename-in、rename-out、
;;; re-export 和冲突检查；它不认识 label / struct / 指令。

(require racket/list
         "sexp.rkt")

(provide module-form?
         clause-form?
         chain-of
         chain<?
         (struct-out module-decl)
         (struct-out require-decl)
         collect-modules
         resolve-modules
         provides->sexp
         parse-extern-provides
         requires->sexp
         module-requires-form?
         parse-extern-requires
         ancestors-and-self)

;; 一个模块只记它自己的声明。命名空间自己的声明由调用方另行索引。
(struct module-decl (name provides requires) #:mutable)

;; target: 模块完整链; prefix: symbol|#f; renames: (listof (cons 外部链 本地链))
(struct require-decl (target prefix renames) #:transparent)

;; ---------------------------------------------------------------------------
;; 形状 / 子句解析
;; ---------------------------------------------------------------------------

(define (module-form? x) (and (form? x) (eq? (car x) 'module)))
(define (clause-form? x key) (and (form? x) (eq? (car x) key)))

(define (chain-of who x)
  (or (normalize-path x)
      (error 'modules "~a: expected a name or a chain of names: ~e" who x)))

(define (chain<? a b)
  (string<? (format "~a" a) (format "~a" b)))

(define (parse-provide-clause c)
  (append*
   (for/list ([spec (in-list (cdr c))])
     (cond
       [(eq? spec '*) (list (cons #f #f))]
       [(and (form? spec) (eq? (car spec) 'rename-out))
        (for/list ([pair (in-list (cdr spec))])
          (unless (and (list? pair) (= 2 (length pair)))
            (error 'modules "rename-out needs (local external) pairs: ~e" pair))
          (cons (chain-of 'rename-out (car pair))
                (chain-of 'rename-out (cadr pair))))]
       [else (define ch (chain-of 'provide spec))
             (list (cons ch ch))]))))

(define (parse-require-clause c)
  (for/list ([r (in-list (cdr c))])
    (cond
      [(and (form? r) (eq? (car r) 'prefix-in))
       (unless (= 3 (length r))
         (error 'modules "prefix-in needs (prefix-in p: 模块): ~e" r))
       (unless (symbol? (cadr r))
         (error 'modules "prefix-in wants a symbol prefix: ~e" r))
       (require-decl (chain-of 'require (caddr r)) (cadr r) '())]
      [(and (form? r) (eq? (car r) 'rename-in))
       (require-decl
        (chain-of 'require (cadr r)) #f
        (for/list ([pair (in-list (cddr r))])
          (unless (and (list? pair) (= 2 (length pair)))
            (error 'modules "rename-in needs (external local) pairs: ~e" pair))
          (cons (chain-of 'rename-in (car pair))
                (chain-of 'rename-in (cadr pair)))))]
      [else (require-decl (chain-of 'require r) #f '())])))

(define (module-decl-of! modules scope)
  (or (hash-ref modules scope #f)
      (let ([m (module-decl scope '() '())])
        (hash-set! modules scope m)
        m)))

;; 收集模块树，返回所有非 module / 非 provide/require 的 item，并带上 scope。
;; 顺序保持源顺序；module 壳被吃掉，由调用方决定是否还要保留它。
(define (collect-modules items scope modules)
  (append*
   (for/list ([it (in-list items)])
     (cond
       [(module-form? it)
        (unless (and (>= (length it) 2) (name? (cadr it)))
          (error 'modules "module needs a name: ~e" it))
        (define full (append scope (list (cadr it))))
        (when (hash-has-key? modules full)
          (error 'modules "module ~s is defined twice" full))
        (hash-set! modules full (module-decl full '() '()))
        (collect-modules (cddr it) full modules)]

       [(clause-form? it 'provide)
        (define m (module-decl-of! modules scope))
        (set-module-decl-provides!
         m (append (module-decl-provides m) (parse-provide-clause it)))
        '()]

       [(clause-form? it 'require)
        (define m (module-decl-of! modules scope))
        (set-module-decl-requires!
         m (append (module-decl-requires m) (parse-require-clause it)))
        '()]

       [else (list (cons scope it))]))))

;; ---------------------------------------------------------------------------
;; 解析
;; ---------------------------------------------------------------------------

(define (ancestors-and-self scope)
  (let loop ([s scope] [acc '()])
    (cond
      [(null? s) (reverse (cons '() acc))]
      [else (loop (drop-right s 1) (cons s acc))])))

(define (target-provides modules extern-provides target allow-unknown?)
  (cond
    [(hash-has-key? modules target)
     (values #t '())]                         ; 当前模块，provides 表里查
    [(hash-has-key? extern-provides target)
     (values #f (hash-ref extern-provides target '()))]
    [allow-unknown? (values #f '())]
    [else
     (error 'modules "undefined module ~s (known: ~a)"
            target (sort (append (hash-keys modules) (hash-keys extern-provides))
                         chain<?))]))

(define (module-imports modules extern-provides provides scope allow-unknown?)
  (define m (hash-ref modules scope))
  (append*
   (for/list ([r (in-list (module-decl-requires m))])
     (define target (require-decl-target r))
     (define-values (local? fixed)
       (target-provides modules extern-provides target allow-unknown?))
     (define rows (if local? (hash-ref provides target '()) fixed))
     (define prefix (require-decl-prefix r))
     (define renames (require-decl-renames r))
     (for/list ([p (in-list rows)])
       (define external (car p))
       (define absolute (cdr p))
       (define renamed (assoc external renames))
       (define local
         (cond
           [renamed (cdr renamed)]
           [prefix (cons (string->symbol (format "~a~a" prefix (car external)))
                         (cdr external))]
           [else external]))
       (cons local absolute)))))

(define (resolve-in-module declarations imports scope local)
  (define hit (assoc local (hash-ref imports scope '())))
  (define full (append scope local))
  (or (and hit (cdr hit))
      (and (hash-ref declarations full #f) full)))

(define (module-provides declarations modules imports own scope)
  (define m (hash-ref modules scope))
  (append*
   (for/list ([p (in-list (module-decl-provides m))])
     (cond
       [(not (car p))                          ; (provide *)
        (for/list ([local (in-list (hash-ref own scope '()))])
          (cons local (append scope local)))]
       [else
        (define abs (resolve-in-module declarations imports scope (car p)))
        (if abs (list (cons (cdr p) abs)) '())]))))

;; 返回 (values imports provides unresolved)
;;   imports    : scope -> ((本地链 . 绝对链) ...)
;;   provides   : scope -> ((外部链 . 绝对链) ...)
;;   unresolved : ((scope 本地链 外部链) ...)
;;
;; allow-providess 是“这个命名空间不处理、但已经由别的命名空间处理”的
;; (module . external) 集合；用于 label 层跳过 struct-only provide。
(define (resolve-modules modules
                         #:declarations [declarations (hash)]
                         #:own [own (hash)]
                         #:extern-provides [extern-provides (hash)]
                         #:allow-provides [allow-provides (hash)]
                         #:allow-unknown-modules? [allow-unknown-modules? #f])
  (define mods (sort (hash-keys modules) chain<?))
  (define imports (make-hash))
  (define provides (make-hash))
  (for ([s (in-list mods)])
    (hash-set! imports s '())
    (hash-set! provides s '()))
  (let loop ([round 0])
    (when (> round 100)
      (error 'modules "module resolution did not converge"))
    (define changed? #f)
    (for ([s (in-list mods)])
      (define new (module-imports modules extern-provides provides s allow-unknown-modules?))
      (unless (equal? new (hash-ref imports s))
        (hash-set! imports s new)
        (set! changed? #t)))
    (for ([s (in-list mods)])
      (define new (module-provides declarations modules imports own s))
      (unless (equal? new (hash-ref provides s))
        (hash-set! provides s new)
        (set! changed? #t)))
    (when changed? (loop (add1 round))))

  ;; 冲突
  (for ([s (in-list mods)])
    (define seen (make-hash))
    (for ([b (in-list (hash-ref imports s))])
      (define prev (hash-ref seen (car b) #f))
      (when (and prev (not (equal? prev (cdr b))))
        (error 'modules "module ~s: ~s is required from two places (~s and ~s)"
               s (car b) prev (cdr b)))
      (hash-set! seen (car b) (cdr b)))
    (for ([b (in-list (hash-ref imports s))])
      (when (member (car b) (hash-ref own s '()))
        (error 'modules "module ~s: ~s is both defined here and required"
               s (car b)))))

  ;; 未解析的 provide：调用方决定是报错还是交给别的命名空间。
  (define unresolved
    (append*
     (for/list ([s (in-list mods)])
       (define got (hash-ref provides s '()))
       (for/list ([p (in-list (module-decl-provides (hash-ref modules s)))]
                  #:when (car p)
                  #:unless (or (assoc (cdr p) got)
                               (hash-ref allow-provides (cons s (cdr p)) #f)))
         (list s (car p) (cdr p))))))

  (values imports provides unresolved))

;; ---------------------------------------------------------------------------
;; 元数据 / 外部 provides
;; ---------------------------------------------------------------------------

;; (provides (module (a) (provide 外部链 绝对链) ...) ...)
(define (provides->sexp provides)
  (sort
   (for/list ([(scope rows) (in-hash provides)])
     (cons 'module
           (cons scope
                 (for/list ([p (in-list rows)])
                   (list 'provide (car p) (cdr p))))))
   (lambda (a b) (chain<? (cadr a) (cadr b)))))

(define (module-provides-form? x)
  (and (form? x) (eq? (car x) 'module) (>= (length x) 2)
       (or (null? (cadr x)) (path? (cadr x)))
       (andmap (lambda (row)
                 (and (form? row) (eq? (car row) 'provide)
                      (= 3 (length row))
                      (path? (cadr row))
                      (path? (caddr row))))
               (cddr x))))

(define (parse-module-provides rows)
  (define h (make-hash))
  (for ([row (in-list rows)])
    (unless (module-provides-form? row)
      (error 'modules "bad module provides row: ~e" row))
    (define scope (cadr row))
    (define pairs (for/list ([p (in-list (cddr row))])
                    (cons (cadr p) (caddr p))))
    (hash-set! h scope (append (hash-ref h scope '()) pairs)))
  h)

(define (require-decl->sexp r)
  (define target (require-decl-target r))
  (define prefix (require-decl-prefix r))
  (define renames (require-decl-renames r))
  (cond
    [prefix (list 'require (list 'prefix-in prefix target))]
    [(pair? renames)
     (list 'require
           (cons 'rename-in
                 (cons target
                       (for/list ([p (in-list renames)])
                         (list (car p) (cdr p))))))]
    [else (list 'require target)]))

(define (requires->sexp modules)
  (sort
   (for/list ([(scope m) (in-hash modules)])
     (cons 'module
           (cons scope (map require-decl->sexp (module-decl-requires m)))))
   (lambda (a b) (chain<? (cadr a) (cadr b)))))

(define (module-requires-form? x)
  (and (form? x) (eq? (car x) 'module) (>= (length x) 2)
       (or (null? (cadr x)) (path? (cadr x)))
       (andmap (lambda (row)
                 (and (form? row) (eq? (car row) 'require)))
               (cddr x))))

(define (parse-module-requires rows)
  (define h (make-hash))
  (for ([row (in-list rows)])
    (unless (module-requires-form? row)
      (error 'modules "bad module requires row: ~e" row))
    (define scope (cadr row))
    (hash-set! h scope (append (hash-ref h scope '()) (cddr row))))
  h)

(define (parse-extern-requires datum tag)
  (cond
    [(null? datum) (make-hash)]
    [(and (form? datum) (eq? (car datum) 'build))
     (define row (assq tag (cdr datum)))
     (if row (parse-extern-requires (cons tag (cdr row)) tag) (make-hash))]
    [(and (form? datum) (eq? (car datum) tag))
     (parse-module-requires (cdr datum))]
    [(and (list? datum) (andmap module-requires-form? datum))
     (parse-module-requires datum)]
    [else
     (error 'modules "~a 只接受 build / (~a ...) / module 行列表: ~e"
            tag tag datum)]))

;; 接受 (build ...) / (label-provides ...) / (struct-provides ...) / module 行列表
(define (parse-extern-provides datum tag)
  (cond
    [(null? datum) (make-hash)]
    [(and (form? datum) (eq? (car datum) 'build))
     (define row (assq tag (cdr datum)))
     (if row (parse-extern-provides (cons tag (cdr row)) tag) (make-hash))]
    [(and (form? datum) (eq? (car datum) tag))
     (parse-module-provides (cdr datum))]
    [(and (list? datum) (andmap module-provides-form? datum))
     (parse-module-provides datum)]
    [else
     (error 'modules "~a 只接受 build / (~a ...) / module 行列表: ~e"
            tag tag datum)]))
