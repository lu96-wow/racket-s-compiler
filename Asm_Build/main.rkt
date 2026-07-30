#lang racket

(require "asm.rkt"
         "module.rkt"
         racket/match)

;; ============================================================
;; 入口：分发 (asm ...) | (module ...) | (link ...)
;; ============================================================

(define (assemble-sexp sexp)
  (match sexp

    ;; ---- 单文件汇编（向后兼容）----
    [`(asm ,word-size ,exts ,body ...)
     (validate-isa! word-size exts)
     (define result (parse-top-level-items body '()))
     (if result
         ;; body 中包含 module 声明 → 走模块路径
         (assemble-modules result word-size exts)
         ;; 纯指令 → 匿名模块，全部本地
         (let ([items (for/list ([i (in-list body)]) (item-sexp->ast i))])
           (assemble items word-size exts)))]

    ;; ---- 独立模块文件： (module 名 body ...) ----
    [`(module ,name ,body ...)
     (define m (parse-module-from-sexp 'module name body '()))
     ;; 匿名 ISA：从模块内容无法推断，用默认 rv64 (rv_i)
     (assemble-modules (list m) 'rv64 '(rv_i))]

    ;; ---- 多文件链接 ----
    [`(link ,word-size ,exts ,file-or-mod ...)
     (validate-isa! word-size exts)
     (define root-mods (link-items->modules file-or-mod))
     (assemble-modules root-mods word-size exts)]

    [_ (error 'asm "expected (asm rv32|rv64 (ext...) ...) or (module name ...) or (link ...)")]))

;; ============================================================
;; 辅助
;; ============================================================

(define (validate-isa! word-size exts)
  (unless (memq word-size '(rv32 rv64))
    (error 'asm "word-size must be rv32 or rv64, got: ~a" word-size))
  (unless (and (list? exts) (andmap symbol? exts))
    (error 'asm "extensions must be (ext...), got: ~a" exts)))

;; 解析 (link ...) 内部的 (file "...") 和 (module ...) 项
(define (link-items->modules items)
  (define mods '())
  (for ([item (in-list items)])
    (match item
      [`(file ,(? string? path))
       (define file-mods (read-module-file path))
       (set! mods (append mods file-mods))]
      [`(module ,name ,sub-body ...)
       (set! mods (cons (parse-module-from-sexp 'module name sub-body '()) mods))]
      [`(module+ ,name ,sub-body ...)
       (set! mods (cons (parse-module-from-sexp 'module+ name sub-body '()) mods))]
      [_ (error 'link "expected (file \"...\") or (module ...), got: ~a" item)]))
  (reverse mods))

;; 读取一个 .asm 文件，返回顶层模块列表
(define (read-module-file path)
  (define p (if (string? path) (string->path path) path))
  (call-with-input-file p
    (λ (in)
      (define s (read in))
      (match s
        [`(module ,name ,body ...)
         (list (parse-module-from-sexp 'module name body '()))]
        [`(module+ ,name ,body ...)
         (list (parse-module-from-sexp 'module+ name body '()))]
        [`(asm ,word-size ,exts ,body ...)
         (validate-isa! word-size exts)
         (define result (parse-top-level-items body
                         (list (string->symbol (path-stem p)))))
         (or result
             ;; 纯指令文件在 link 上下文中也包装为匿名模块
             (let* ([anon-name (list (string->symbol (path-stem p)))]
                    [items (for/list ([i (in-list body)]) (item-sexp->ast i))])
               (list (mod-info anon-name 'module '() '() items '()))))]
        [_ (error 'link "file ~a must contain (module ...) or (asm ...), got: ~a" path s)]))))

;; 路径辅助 — 统一接受 string 或 path
(define (->string v) (if (string? v) v (path->string v)))

(define (path-remove-ext p)
  (regexp-replace #rx"\\.[^.]*$" (->string p) ""))

(define (path-stem p)
  (path-remove-ext (last (string-split (->string p) "/"))))

;; ============================================================
;; assemble-file：读取一个文件，自动检测类型
;; ============================================================
(define (assemble-file path)
  (call-with-input-file path
    (λ (in)
      (let loop ()
        (define s (read in))
        (if (eof-object? s) #"" (assemble-sexp s))))))

(provide assemble-sexp assemble-file)
