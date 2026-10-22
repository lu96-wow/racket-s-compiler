#lang racket

;; 模块处理 — 被 main.rkt (for-syntax) 在编译期调用
;; 输入：S 表达式列表
;; 输出：S 表达式列表（asm-label/asm-insn/asm-space 的 S 表达式形式）

(provide process-modules)

;; module-def: (list path provides requires body)
;;   path: (listof symbol)
;;   provides: (listof symbol)
;;   requires: (listof (cons/c (listof symbol) (listof symbol)))
;;   body: (listof s-expression)
(struct module-def (path provides requires body children) #:transparent)

;; 从 body items 中收集模块定义
(define (parse-body items [parent-path '()])
  (define anon-body '())
  (define anon-provides '())
  (define anon-requires '())
  (define sub-mods '())

  (for ([item (in-list items)])
    (match item
      [`(module ,name ,sub ...)
       (define path (append parent-path (path->list name)))
       (define parsed (parse-module-body sub path))
       (set! sub-mods (cons parsed sub-mods))]

      [`(module+ ,name ,sub ...)
       (define path (append parent-path (path->list name)))
       (define parsed (parse-module-body sub path 'module+))
       (set! sub-mods (cons parsed sub-mods))]

      [`(provide ,(? symbol? syms) ...)
       (set! anon-provides (append anon-provides syms))]

      [`(require ,mod-ref ,(? symbol? syms) ...)
       (define req-path (path->list mod-ref))
       (set! anon-requires (cons (cons req-path syms) anon-requires))]

      [_ (set! anon-body (cons item anon-body))]))

  (define anon
    (module-def parent-path
                (reverse anon-provides)
                (reverse anon-requires)
                (reverse anon-body)
                '()))

  (if (null? sub-mods)
      (list anon)
      (cons anon (reverse sub-mods))))

(define (parse-module-body items path [kind 'module])
  (define provides '())
  (define requires '())
  (define body '())
  (define children '())

  (for ([item (in-list items)])
    (match item
      [`(provide ,(? symbol? syms) ...)
       (set! provides (append provides syms))]
      [`(require ,mod-ref ,(? symbol? syms) ...)
       (define req-path (path->list mod-ref))
       (set! requires (cons (cons req-path syms) requires))]
      [`(module ,name ,sub ...)
       (define child-path (append path (path->list name)))
       (define parsed (parse-module-body sub child-path))
       (set! children (cons parsed children))]
      [`(module+ ,name ,sub ...)
       (define child-path (append path (path->list name)))
       (define parsed (parse-module-body sub child-path 'module+))
       (set! children (cons parsed children))]
      [_ (set! body (cons item body))]))

  (module-def path
              (reverse provides)
              (reverse requires)
              (reverse body)
              (reverse children)))

(define (path->list s)
  (match s
    [(? symbol?) (list s)]
    [(list (? symbol? segs) ...) segs]
    [_ (error 'module "invalid module path: ~a" s)]))

(define (collect-all defs)
  (let loop ([defs defs])
    (append defs
            (append-map (λ (d) (loop (module-def-children d))) defs))))

(define (collect-labels items)
  (for/set ([item (in-list items)]
            #:when (match item [`(label ,(? symbol? _)) #t] [_ #f]))
    (match item [`(label ,name) name])))

(define (build-exports defs)
  (for/hash ([d (in-list defs)])
    (define path (module-def-path d))
    (define provides (module-def-provides d))
    (define body-syms (collect-labels (module-def-body d)))
    (define exports
      (if (null? provides) body-syms (list->set provides)))
    (for ([s (in-list provides)])
      (unless (set-member? body-syms s)
        (error 'module "module ~a provides undefined symbol: ~a" path s)))
    (values path exports)))

(define (build-imports defs exports-table)
  (for/hash ([d (in-list defs)])
    (define path (module-def-path d))
    (define im (make-hash))
    (for ([req (in-list (module-def-requires d))])
      (match-define (cons target-path syms) req)
      (unless (hash-has-key? exports-table target-path)
        (error 'module "module ~a requires unknown module: ~a"
               path target-path))
      (define target-exports (hash-ref exports-table target-path))
      (for ([s (in-list syms)])
        (unless (set-member? target-exports s)
          (error 'module "module ~a does not provide ~a"
                 target-path s))
        (when (hash-has-key? im s)
          (error 'module "ambiguous import ~a in module ~a" s path))
        (hash-set! im s (append target-path (list s)))))
    (values path im)))

(define (depth-first-order defs)
  (define order '())
  (let dfs ([ds defs])
    (for ([d (in-list ds)])
      (set! order (cons d order))
      (dfs (module-def-children d))))
  (reverse order))

(define (resolve-sym arg locals parent-locals im module-path)
  (cond
    [(exact-integer? arg) arg]
    [(set-member? locals arg)
     (if (null? module-path) arg (append module-path (list arg)))]
    [(hash-ref im arg #f)]
    [(set-member? parent-locals arg)
     (let ([pp (drop-right module-path 1)])
       (if (null? pp) arg (append pp (list arg))))]
    [else arg]))

(define (parse-space args)
  (match args
    [(list (? exact-integer? n)) n]
    [(list (and unit (or 'KB 'MB 'GB)) (? exact-integer? n))
     (* n (case unit [(KB) 1024] [(MB) 1048576] [(GB) 1073741824]))]
    [_ (error 'space "invalid space: ~a" args)]))

(define (rewrite-item item module-path locals parent-locals im)
  (match item
    [`(label ,name)
     `(asm-label ',(if (null? module-path) name
                       (append module-path (list name))))]
    [`(space ,args ...)
     (define sz (parse-space args))
     `(asm-space ,sz)]
    [`(,(? symbol? mnemonic) ,args ...)
     `(asm-insn ',mnemonic
                ',(for/list ([arg (in-list args)])
                    (resolve-sym arg locals parent-locals im module-path)))]
    [_ (error 'module "unexpected item in module ~a: ~a" module-path item)]))

(define (flatten-module d exports import-maps)
  (define path (module-def-path d))
  (define im (hash-ref import-maps path (hash)))

  (define effective-im
    (if (null? path)
        (hash)
        (let ([pp (drop-right path 1)])
          (if (hash-has-key? import-maps pp)
              (hash-ref import-maps pp)
              (hash)))))
  (define merged-im (make-hash))
  (for ([(k v) (in-hash effective-im)]) (hash-set! merged-im k v))
  (for ([(k v) (in-hash im)]) (hash-set! merged-im k v))

  (define locals (collect-labels (module-def-body d)))
  (define parent-locals
    (if (null? path)
        (set)
        (let ([pp (drop-right path 1)])
          (if (hash-has-key? exports pp)
              (hash-ref exports pp)
              (set)))))

  (for/list ([item (in-list (module-def-body d))])
    (rewrite-item item path locals parent-locals merged-im)))

(define (process-modules items)
  (define top-defs (parse-body items))
  (define all-defs (collect-all top-defs))
  (define exports (build-exports all-defs))
  (define imports (build-imports all-defs exports))
  (define ordered (depth-first-order all-defs))

  (append-map (λ (d) (flatten-module d exports imports)) ordered))
