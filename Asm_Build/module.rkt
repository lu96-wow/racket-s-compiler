#lang racket

(require "asm.rkt"
         racket/match
         racket/set)

;; ============================================================
;; 数据结构
;; ============================================================

;; 模块路径: (listof symbol)，如 (math helpers)
;; 限定名:   (listof symbol)，如 (math helpers helper1)

(struct mod-info (name kind provides requires body children)
  #:transparent)
;; name: 模块绝对路径 (listof symbol)
;; kind: 'module | 'module+
;; provides: (listof symbol) — 只导出裸名，不含路径前缀
;; requires: (listof require-spec)
;; body: (listof asm-item) — 指令/标签/space，不含 provide/require 和子模块
;; children: (listof mod-info) — 直接子模块

(struct require-spec (target-path symbols)
  #:transparent)
;; target-path: (listof symbol) — 目标模块的绝对路径
;; symbols: (listof symbol) — 要导入的符号名；空列表 = 全部导入

;; ============================================================
;; S 表达式 → AST + 模块
;; ============================================================

;; 将单个指令/标签/space S 表达式转为 AST
;; 不处理 provide/require/module — 这些在模块解析层处理
(define (item-sexp->ast item)
  (match item
    [`(label ,(? symbol? n))
     (asm-label n)]
    [`(li ,(? symbol? r) ,(? exact-integer? v))
     (asm-insn 'li (list r v))]
    [`(space ,args ...)
     #:when (space-size args)
     (asm-space (space-size args))]
    [`(,(? symbol? m) ,args ...)
     (asm-insn m args)]
    [_ (error 'module "unexpected item: ~a" item)]))

(define (space-size form)
  (match form
    [(list (? exact-integer? n)) n]
    [(list (and unit (or 'KB 'MB 'GB)) (? exact-integer? n))
     (* n (case unit [(KB) 1024] [(MB) 1048576] [(GB) 1073741824]))]
    [_ #f]))

;; 模块路径的 S 表达式: symbol 或 (list symbol ...)
(define (parse-mod-path s)
  (match s
    [(? symbol?) (list s)]
    [(list (? symbol? segs) ...) segs]
    [_ (error 'module "invalid module path: ~a" s)]))

;; 递归解析 (module path body ...) 或 (module+ path body ...)
;; parent-path: 父模块的绝对路径，用于构造子模块路径
(define (parse-module-from-sexp kind mod-path-sexp body-sexps parent-path)
  (define path (append parent-path (parse-mod-path mod-path-sexp)))
  (define provides '())
  (define requires '())
  (define body '())
  (define children '())

  (for ([item (in-list body-sexps)])
    (match item
      ;; (provide sym ...)
      [`(provide ,(? symbol? syms) ...)
       (set! provides (append provides syms))]
      ;; (require mod-path) 或 (require mod-path sym ...)
      [`(require ,mod-ref ,more ...)
       (match-define (cons req-path syms)
         (parse-require-spec mod-ref more))
       (set! requires (cons (require-spec (append parent-path req-path) syms) requires))]
      ;; 嵌套 module
      [`(module ,sub-name ,sub-body ...)
       (set! children
             (cons (parse-module-from-sexp 'module sub-name sub-body path)
                   children))]
      ;; 嵌套 module+
      [`(module+ ,sub-name ,sub-body ...)
       (set! children
             (cons (parse-module-from-sexp 'module+ sub-name sub-body path)
                   children))]
      ;; 普通指令/标签/space
      [_ (set! body (cons (item-sexp->ast item) body))]))

  (mod-info path kind
            (reverse provides)
            (reverse requires)
            (reverse body)
            (reverse children)))

;; 解析 require 的目标路径和符号列表
;; mod-ref: symbol | (symbol ...) — 被 require 的模块路径（相对当前模块的父路径）
;; more:   (listof symbol) — 要导入的符号名
;; 返回: (cons target-path symbol-list)
;;   target-path 是相对路径（后续由调用者加上 parent-path）
(define (parse-require-spec mod-ref more)
  (define req-path (parse-mod-path mod-ref))
  ;; 检查 more 全是符号
  (for ([s (in-list more)])
    (unless (symbol? s)
      (error 'module "invalid require symbol: ~a" s)))
  (cons req-path more))

;; ============================================================
;; 从 S 表达式入口解析顶层模块列表
;; ============================================================

;; 从 (asm ...) 或 (link ...) 的 body 中提取所有顶层 item
;; 检测到 (module ...) / (module+ ...) 就递归解析
;; 非模块 item 归入匿名模块（路径为 (filename)）
(define (parse-top-level-items body-sexps anonymous-name)
  (define anon-body '())
  (define anon-provides '())
  (define anon-requires '())
  (define modules '())
  (define seen-module? #f)

  (for ([item (in-list body-sexps)])
    (match item
      [`(module ,name ,body ...)
       (set! seen-module? #t)
       (set! modules
             (cons (parse-module-from-sexp 'module name body '())
                   modules))]
      [`(module+ ,name ,body ...)
       (set! seen-module? #t)
       (set! modules
             (cons (parse-module-from-sexp 'module+ name body '())
                   modules))]
      [`(provide ,(? symbol? syms) ...)
       (set! anon-provides (append anon-provides syms))]
      [`(require ,mod-ref ,more ...)
       (match-define (cons req-path syms) (parse-require-spec mod-ref more))
       (set! anon-requires (cons (require-spec req-path syms) anon-requires))]
      [_ (set! anon-body (cons (item-sexp->ast item) anon-body))]))

  (cond
    ;; 有显式模块：匿名部分也包装成模块
    [seen-module?
     (define anon-mod
       (mod-info anonymous-name 'module
                 (reverse anon-provides)
                 (reverse anon-requires)
                 (reverse anon-body)
                 '()))
     (cons anon-mod (reverse modules))]
    ;; 无显式模块但有 require/provide：包装为匿名模块
    [(or (pair? anon-requires) (pair? anon-provides))
     (list (mod-info anonymous-name 'module
                     (reverse anon-provides)
                     (reverse anon-requires)
                     (reverse anon-body)
                     '()))]
    ;; 全是普通指令，没有 require/provide → 返回 #f，走旧版平铺路径
    [else #f]))

;; ============================================================
;; 展平
;; ============================================================

;; 递归收集所有模块（含子模块）到注册表
;; 返回值: (hash/c (listof symbol) mod-info)
(define (collect-modules root-mods)
  (define registry (make-hash))
  (let loop ([mods root-mods])
    (for ([m (in-list mods)])
      (define path (mod-info-name m))
      (when (hash-has-key? registry path)
        (error 'module "duplicate module name: ~a" path))
      (hash-set! registry path m)
      (loop (mod-info-children m))))
  registry)

;; 为目标模块构建其可见的符号集合
;; 返回: (setof symbol) — 模块内可直接使用的裸名集合
;; module+: 额外包含祖先模块的所有可见符号
(define (visible-symbols m registry)
  (define local-labels
    (for/set ([item (in-list (mod-info-body m))]
              #:when (asm-label? item))
      (asm-label-name item)))
  (define imported
    (for/set ([req (in-list (mod-info-requires m))]
              #:when (null? (require-spec-symbols req)))
      ;; 全量导入 → 先不展开，由 import map 构建时处理
      ;; 这里只需要从 export-table 取
      #f))
  ;; TODO: 处理全量导入的符号名收集
  ;; 暂时忽略 imported 展开（在 build-import-maps 中处理）
  (define own-syms local-labels)

  (if (eq? (mod-info-kind m) 'module+)
      ;; module+: 合并祖先的可见符号
      (let merge-ancestors ([path (mod-info-name m)])
        (cond
          [(null? path) own-syms]
          [(null? (cdr path))
           ;; path = (root)，没有祖先了
           own-syms]
          [else
           (define parent-path (drop-right path 1))
           (define parent (hash-ref registry parent-path #f))
           (if parent
               (set-union own-syms
                          (for/set ([item (in-list (mod-info-body parent))]
                                    #:when (asm-label? item))
                            (asm-label-name item)))
               own-syms)]))
      own-syms))

;; 为每个模块构建 import map
;; 返回: (hash/c (listof symbol) (hash/c symbol (listof symbol)))
;;   import-map: 模块路径 → { 本地裸名 → 目标限定名 }
(define (build-import-maps registry export-tables)
  (define import-maps (make-hash))

  (for ([(path m) (in-hash registry)])
    (define im (make-hash))
    (for ([req (in-list (mod-info-requires m))])
      (define target-path (require-spec-target-path req))
      (define target (hash-ref registry target-path #f))
      (unless target
        (error 'module "module ~a requires unknown module: ~a" path target-path))
      (define target-exports (hash-ref export-tables target-path))
      (define syms (require-spec-symbols req))

      (if (null? syms)
          ;; 全量导入：导入目标模块 provides 的所有符号
          (for ([sym (in-set target-exports)])
            (when (hash-has-key? im sym)
              (error 'module "ambiguous import ~a in module ~a (conflict with previous require)"
                     sym path))
            (hash-set! im sym (append target-path (list sym))))
          ;; 选择性导入
          (for ([sym (in-list syms)])
            (unless (set-member? target-exports sym)
              (error 'module "module ~a does not provide ~a (required by ~a)"
                     target-path sym path))
            (when (hash-has-key? im sym)
              (error 'module "ambiguous import ~a in module ~a (conflict with previous require)"
                     sym path))
            (hash-set! im sym (append target-path (list sym))))))

    ;; module+：额外继承父模块的 import map
    (when (eq? (mod-info-kind m) 'module+)
      (define parent-path (drop-right path 1))
      (when (and (pair? parent-path) (hash-has-key? registry parent-path))
        (define parent-im (hash-ref import-maps parent-path (hash)))
        (for ([(sym qname) (in-hash parent-im)])
          (unless (hash-has-key? im sym)
            (hash-set! im sym qname)))))

    (hash-set! import-maps path im))

  import-maps)

;; 构建导出表：每个模块 provide 的符号集合
(define (build-export-tables registry)
  (define tables (make-hash))
  (for ([(path m) (in-hash registry)])
    (define local-labels
      (for/set ([item (in-list (mod-info-body m))]
                #:when (asm-label? item))
        (asm-label-name item)))
    (define provided (mod-info-provides m))
    ;; 验证：provide 的符号必须在模块内定义
    (for ([sym (in-list provided)])
      (unless (set-member? local-labels sym)
        (error 'module "module ~a provides undefined symbol: ~a" path sym)))
    (define exports
      (if (null? provided)
          local-labels   ;; 没写 provide → 默认导出所有（仅顶层匿名模块）
          (for/set ([sym (in-list provided)]) sym)))
    (hash-set! tables path exports))
  tables)

;; 重写并展平所有模块
;; module-order: 模块路径列表，按声明顺序
(define (rewrite-and-flatten registry import-maps module-order)
  (define all-items '())

  (for ([path (in-list module-order)])
    (define m (hash-ref registry path))
    (define im (hash-ref import-maps path))
    (define parent-im
      (if (eq? (mod-info-kind m) 'module+)
          (let ([pp (drop-right path 1)])
            (if (and (pair? pp) (hash-has-key? registry pp))
                (hash-ref import-maps pp (hash))
                (hash)))
          (hash)))

    ;; 收集模块内定义的本地 label 名
    (define local-labels
      (for/set ([item (in-list (mod-info-body m))]
                #:when (asm-label? item))
        (asm-label-name item)))

    ;; module+ 额外可见的父模块符号
    (define parent-local-labels
      (if (eq? (mod-info-kind m) 'module+)
          (let ([pp (drop-right path 1)])
            (if (and (pair? pp) (hash-has-key? registry pp))
                (for/set ([item (in-list (mod-info-body (hash-ref registry pp)))]
                          #:when (asm-label? item))
                  (asm-label-name item))
                (set)))
          (set)))

    (for ([item (in-list (mod-info-body m))])
      (define new-item
        (match item
          ;; 重命名 label：module 路径 + 本地名
          [(asm-label name)
           (asm-label (append path (list name)))]
          ;; 重写指令中的符号引用
          [(asm-insn mnemonic args)
           (asm-insn mnemonic
             (for/list ([arg (in-list args)])
               (resolve-symbol arg local-labels parent-local-labels im parent-im path)))]
          ;; space 不变
          [_ item]))
      (set! all-items (cons new-item all-items))))

  (reverse all-items))

;; 解析指令参数中的符号引用
;; local-labels: 本地定义的 label 名
;; parent-labels: 父模块的 label（仅 module+ 有效）
;; im: 当前模块的 import map
;; parent-im: 父模块的 import map（仅 module+ 有效）
;; module-path: 当前模块路径
(define (resolve-symbol arg local-labels parent-labels im parent-im module-path)
  (cond
    [(exact-integer? arg) arg]
    [(reg-num arg) => (λ (n) arg)]     ;; 寄存器 → 保持原样
    [(set-member? local-labels arg)
     (append module-path (list arg))]  ;; 本地 label → 限定名
    [(hash-ref im arg #f)]             ;; 显式 import → 目标限定名
    [(set-member? parent-labels arg)
     (let ([pp (drop-right module-path 1)])
       (append pp (list arg)))]        ;; 父模块 label → 父路径限定名
    [(hash-ref parent-im arg #f)]      ;; 父模块 import → 父的映射
    [else (error 'module "unresolved symbol ~a in module ~a" arg module-path)]))

;; ============================================================
;; 顶层入口
;; ============================================================

;; 从模块列表组装成字节码
;; root-mods: (listof mod-info) — 顶层模块（按 link 声明顺序）
;; word-size: 'rv32 | 'rv64
;; exts: (listof symbol) — 扩展列表
(define (assemble-modules root-mods word-size exts)
  ;; 1. 收集所有模块到注册表
  (define registry (collect-modules root-mods))

  ;; 2. 构建导出表
  (define export-tables (build-export-tables registry))

  ;; 3. 构建导入表（含校验）
  (define import-maps (build-import-maps registry export-tables))

  ;; 4. 确定展平顺序：深度优先，按声明顺序
  (define module-order (compute-module-order root-mods registry))

  ;; 5. 重写 + 展平
  (define flat-items (rewrite-and-flatten registry import-maps module-order))

  ;; 6. 喂给现有汇编引擎
  (assemble flat-items word-size exts))

;; 深度优先遍历，按声明顺序排列模块
(define (compute-module-order root-mods registry)
  (define order '())
  (let dfs ([mods root-mods])
    (for ([m (in-list mods)])
      (set! order (cons (mod-info-name m) order))
      (dfs (mod-info-children m))))
  (reverse order))

;; ============================================================
;; 供 main.rkt 使用的辅助函数
;; ============================================================

(provide mod-info mod-info?
         mod-info-name mod-info-kind mod-info-provides
         mod-info-requires mod-info-body mod-info-children
         require-spec require-spec?
         require-spec-target-path require-spec-symbols
         item-sexp->ast
         parse-module-from-sexp
         parse-top-level-items
         assemble-modules)
