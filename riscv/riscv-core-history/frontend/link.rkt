#lang racket
;;; frontend/link.rkt
;;;
;;; 第二步：模块名字解析。
;;;
;;; 输入：collect 出来的 program。
;;; 输出：linked —— 每个模块的 imports / exports，以及全程序导出集合。
;;;
;;; 这一层只关心：
;;;   - require 的目标模块是否存在；
;;;   - provide / require / rename / prefix 的名字如何变成完整链；
;;;   - 可见性冲突；
;;;   - 循环 require 的不动点。
;;;
;;; 它不关心 func 的 body、vreg、block、指令。

(require "sexp.rkt"
         "program.rkt")

(provide link-program)

(define (link-program prog)
  (define mods (program-modules prog))
  (define names (sort (hash-keys mods) chain<?))

  ;; require 的目标必须存在；先在入口报，避免空 exports 把错误拖后。
  (for ([name (in-list names)])
    (define m (must-module mods name))
    (for ([r (in-list (module-requires m))])
      (unless (hash-has-key? mods (require-spec-target r))
        (error 'link
               "module ~a requires undefined module ~a"
               (chain->string name)
               (chain->string (require-spec-target r))))))

  ;; imports / exports 初始为空；provide * 只依赖自己的定义，会先长出来。
  (define imports (make-hash))
  (define exports (make-hash))
  (for ([name (in-list names)])
    (hash-set! imports name '())
    (hash-set! exports name '()))

  (let loop ([round 0])
    (when (> round 1000)
      (error 'link "module resolution did not converge"))
    (define changed? #f)

    ;; imports 由对方当前 exports 算。
    (for ([name (in-list names)])
      (define m (must-module mods name))
      (define new-imports
        (compute-imports m exports))
      (unless (equal? new-imports (hash-ref imports name))
        (hash-set! imports name new-imports)
        (set! changed? #t)))

    ;; exports 由自己的 provide 规则 + 新 imports 算（支持 re-export）。
    (for ([name (in-list names)])
      (define m (must-module mods name))
      (define new-exports
        (compute-exports prog m imports))
      (unless (equal? new-exports (hash-ref exports name))
        (hash-set! exports name new-exports)
        (set! changed? #t)))

    (when changed? (loop (add1 round))))

  ;; 收敛后一次性校验，错误信息不会被中间状态污染。
  (validate-provides! prog mods imports names)
  (validate-renames! mods exports names)
  (validate-own-defs! prog mods names)

  (define final-exports
    (for/hash ([name (in-list names)])
      (values name (dedupe-exports! prog mods exports name))))

  (define final-imports
    (for/hash ([name (in-list names)])
      (values name (dedupe-imports! prog mods imports name))))

  (define all-exports
    (sort (remove-duplicates
           (append* (for/list ([name (in-list names)])
                      (map cdr (hash-ref final-exports name)))))
          chain<?))

  (linked prog final-imports final-exports all-exports))

;; ---------------------------------------------------------------------------
;; 不动点里用的两个函数
;; ---------------------------------------------------------------------------

;; 一个模块从 require 目标当前的 exports 得到哪些 (本地链 . 完整链) 绑定。
(define (compute-imports m exports)
  (append*
   (for/list ([r (in-list (module-requires m))])
     (define target-exports (hash-ref exports (require-spec-target r) '()))
     (for/list ([e (in-list target-exports)])
       (define external (car e))
       (define absolute (cdr e))
       (define renamed (find-rename (require-spec-renames r) external))
       (define local
         (cond
           [renamed (rename-local renamed)]
           [(require-spec-prefix r)
            (cons (require-spec-prefix r) external)]
           [else external]))
       (cons local absolute)))))

(define (find-rename renames external)
  (findf (lambda (r) (equal? (rename-external r) external)) renames))

;; 一个模块根据 provide 子句得到哪些 (外部链 . 完整链) 导出。
;; 显式 provide 可以 re-export 一个 require 进来的名字。
(define (compute-exports prog m imports)
  (define module-imports (hash-ref imports (module-name m) '()))
  (append*
   (for/list ([p (in-list (module-provides m))])
     (define local (provide-spec-local p))
     (cond
       [(not local)                         ; (provide *)
        (for/list ([own (in-list (module-own-defs m))])
          (cons own (append (module-name m) own)))]
       [else
        (define external (provide-spec-external p))
        (define absolute
          (resolve-local (program-defs prog) (module-name m) module-imports local))
        (if absolute (list (cons external absolute)) '())]))))

;; ---------------------------------------------------------------------------
;; 校验
;; ---------------------------------------------------------------------------

(define (must-module mods name)
  (or (hash-ref mods name #f)
      (error 'link "undefined module ~a" (chain->string name))))

;; 每个显式 provide 都必须解得出来。provide * 只列自己的定义，一定解得出来。
(define (validate-provides! prog mods imports names)
  (for ([name (in-list names)])
    (define m (must-module mods name))
    (define module-imports (hash-ref imports name '()))
    (for ([p (in-list (module-provides m))])
      (define local (provide-spec-local p))
      (when local
        (unless (resolve-local (program-defs prog) name module-imports local)
          (error 'link
                 "module ~a provides ~a, but it is not defined or imported"
                 (chain->string name)
                 (chain->string local)))))))

;; rename-in 的每个外部名都必须真的被目标模块导出。
(define (validate-renames! mods exports names)
  (for ([name (in-list names)])
    (define m (must-module mods name))
    (for ([r (in-list (module-requires m))])
      (define target-exports (hash-ref exports (require-spec-target r) '()))
      (for ([rn (in-list (require-spec-renames r))])
        (unless (assoc (rename-external rn) target-exports)
          (error 'link
                 "module ~a renames ~a from ~a, but that name is not exported"
                 (chain->string name)
                 (chain->string (rename-external rn))
                 (chain->string (require-spec-target r))))))))

;; own-defs 和 defs 表必须一致；这是 collect 的不变量。
(define (validate-own-defs! prog mods names)
  (for ([name (in-list names)])
    (define m (must-module mods name))
    (for ([local (in-list (module-own-defs m))])
      (define global (append name local))
      (unless (hash-has-key? (program-defs prog) global)
        (error 'link
               "internal: module ~a lists ~a but the definition is missing"
               (chain->string name)
               (chain->string local))))))

;; ---------------------------------------------------------------------------
;; 去重 + 冲突检查
;; ---------------------------------------------------------------------------

;; 同一个本地名只能指向一个完整名；并且不能和本模块直接定义的全局名撞。
(define (dedupe-imports! prog mods imports name)
  (define m (must-module mods name))
  (define raw (hash-ref imports name '()))
  (define seen (make-hash))

  (for ([b (in-list raw)])
    (define local (car b))
    (define absolute (cdr b))
    (define previous (hash-ref seen local #f))
    (when (and previous (not (equal? previous absolute)))
      (error 'link
             "module ~a imports ~a from two different globals (~a and ~a)"
             (chain->string name)
             (chain->string local)
             (chain->string previous)
             (chain->string absolute)))
    (hash-set! seen local absolute))

  (for ([local (in-hash-keys seen)])
    (define global (append name local))
    (when (hash-has-key? (program-defs prog) global)
      (error 'link
             "module ~a: ~a is both defined here and imported"
             (chain->string name)
             (chain->string local))))

  (sort (for/list ([(local absolute) (in-hash seen)])
          (cons local absolute))
        (lambda (a b) (chain<? (car a) (car b)))))

;; 同一个外部名只能指向一个完整名；导出的完整名必须在 defs 里。
(define (dedupe-exports! prog mods exports name)
  (define raw (hash-ref exports name '()))
  (define seen (make-hash))

  (for ([e (in-list raw)])
    (define external (car e))
    (define absolute (cdr e))
    (define previous (hash-ref seen external #f))
    (when (and previous (not (equal? previous absolute)))
      (error 'link
             "module ~a exports ~a as two different globals (~a and ~a)"
             (chain->string name)
             (chain->string external)
             (chain->string previous)
             (chain->string absolute)))
    (unless (hash-has-key? (program-defs prog) absolute)
      (error 'link
             "module ~a exports ~a, but ~a is not defined"
             (chain->string name)
             (chain->string external)
             (chain->string absolute)))
    (hash-set! seen external absolute))

  (sort (for/list ([(external absolute) (in-hash seen)])
          (cons external absolute))
        (lambda (a b) (chain<? (car a) (car b)))))
