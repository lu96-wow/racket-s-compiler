#lang racket

(require "asm.rkt"
         racket/match
         racket/set)

;; ============================================================
;; 作用域分析 + 资源分配 + 名字消解 + 回收 — 统一入口
;;
;; 将 env.rkt 的功能吸收进来，形成完整流水线：
;;
;;   items (含 env-let-reg)
;;     → build-scope-tree     （Pass 1: 构建作用域树）
;;     → escape-analysis      （Pass 2: 逃逸分析，原型留空）
;;     → compute-lifetimes    （Pass 3: 推导生命周期）
;;     → allocate-resources   （Pass 4: 分配物理资源）
;;     → resolve-names        （Pass 5: 虚拟名 → 物理名）
;;     → emit-reclamations    （Pass 6: 插入回收指令 + 展平）
;;
;; 数据符号化（A）和内存管理（B）在这里汇合：
;;   - binding-info 记录"一段资源"的元信息
;;   - 资源类型（寄存器/内存块）决定分配和回收策略
;;   - 逃逸状态决定能不能自动回收
;;   - strategy（stack/bump/gc/manual）决定如何分配、如何回收
;; ============================================================

;; ============================================================
;; AST：let-reg 结构（原 env.rkt）
;; ============================================================

(struct env-let-reg (bindings body) #:transparent)
;; bindings: (listof (cons/c symbol (or/c 'get-reg symbol?)))
;;   spec='get-reg → 自动分配; spec=寄存器名 → 显式绑定
;; body:     (listof asm-item) — 可嵌套 env-let-reg

;; ============================================================
;; 资源池
;; ============================================================

(define register-pool
  (for/list ([i (in-range 1 32)])
    (string->symbol (format "x~a" i))))  ;; x1-x31

;; 从池中选第一个空闲寄存器
(define (pick-register used)
  (for/or ([r (in-list register-pool)])
    (and (not (set-member? used r)) r)))

;; ============================================================
;; 数据结构
;; ============================================================

;; 作用域树的节点
(struct scope-node
  (id source bindings body)
  #:transparent)
;; id       — gensym
;; source   — 'root | 'let-reg | 'module | 'proc
;; bindings — (hash/c symbol binding-info)
;; body     — (listof item)，混合 leaf-item 和 scope-node

;; 绑定信息
(struct binding-info
  (name resource size region spec escapes? lifetime physical)
  #:transparent)
;; name     — 符号名
;; resource — 'register | 'mem-block
;; size     — 字节数（寄存器=0）
;; region   — symbol | #f（内存区域名）
;; spec     — 'get-reg | 寄存器符号（原始绑定规格）
;; escapes? — boolean
;; lifetime — gensym | 'unknown
;; physical — symbol | #f（分配后的物理名，如 x3 或地址偏移）

;; 策略：封装分配器和回收器
(struct strategy
  (name allocator reclaimer)
  #:transparent)
;; allocator  — (λ binding scope-id pool-state) → (values physical pool-state)
;; reclaimer  — (λ binding scope-id) → (listof asm-item)

;; 池状态：(setof symbol) — 当前已占用的物理资源名
(define initial-pool-state (set))

;; ============================================================
;; Pass 1: 构建作用域树
;; ============================================================

(define (build-scope-tree items [source 'root])
  (define id (gensym 'scope))
  (define-values (_ expanded-body)
    (expand-scope-body items id))
  (scope-node id source (hash) expanded-body))

(define (build-scope-tree-with-bindings items source bindings)
  (define id (gensym 'scope))
  (define-values (_ expanded-body)
    (expand-scope-body items id))
  (scope-node id source bindings expanded-body))

(define (expand-scope-body items parent-id)
  (define bindings (make-hash))
  (define expanded '())

  (for ([item (in-list items)])
    (match item
      [(env-let-reg binding-pairs body)
       (define child-bindings (make-hash))
       (for ([pair (in-list binding-pairs)])
         (match-define (cons name spec) pair)
         (hash-set! child-bindings name (make-binding name spec)))
       (define child (build-scope-tree-with-bindings
                       body 'let-reg child-bindings))
       (set! expanded (cons child expanded))]
      [_ (set! expanded (cons item expanded))]))

  (values bindings (reverse expanded)))

(define (make-binding name spec)
  (binding-info name 'register 0 #f spec #f 'unknown #f))

(define (binding-spec info) (binding-info-spec info))

;; ============================================================
;; Pass 2: 收集所有绑定（调试用）
;; ============================================================

(define (collect-all-bindings root)
  (define all (make-hash))
  (let traverse ([node root])
    (for ([(name info) (in-hash (scope-node-bindings node))])
      (hash-update! all name
        (λ (entries) (cons (cons info (scope-node-id node)) entries))
        '()))
    (for ([item (in-list (scope-node-body node))])
      (when (scope-node? item) (traverse item))))
  all)

;; ============================================================
;; Pass 3: 逃逸分析（原型：全部不逃逸）
;; ============================================================

(define (escape-analysis binding owning-scope-id scope-tree body)
  ;; TODO: 逃逸条件
  ;;   1. store 到作用域外
  ;;   2. return 返回值
  ;;   3. 消息发送到其他进程
  ;;   4. 闭包捕获
  (struct-copy binding-info binding [escapes? #f]))

;; ============================================================
;; Pass 4: 推导生命周期
;; ============================================================

(define (compute-lifetimes root)
  (let traverse ([node root])
    (define new-bindings (make-hash))
    (for ([(name info) (in-hash (scope-node-bindings node))])
      (define escaped? (binding-info-escapes? info))
      (hash-set! new-bindings name
        (if escaped?
            info
            (struct-copy binding-info info [lifetime (scope-node-id node)]))))
    (define new-body
      (for/list ([item (in-list (scope-node-body node))])
        (if (scope-node? item) (traverse item) item)))
    (struct-copy scope-node node [bindings new-bindings] [body new-body])))

;; ============================================================
;; Pass 5: 分配物理资源
;; ============================================================

;; 返回更新后的作用域树（binding-info.physical 已设置）
(define (allocate-resources root strat)
  (let traverse ([node root] [pool initial-pool-state])
    (define alloc (strategy-allocator strat))
    (define new-bindings (make-hash))
    (define new-pool pool)

    (for ([(name info) (in-hash (scope-node-bindings node))])
      (match-define (cons physical next-pool)
        (alloc info node new-pool))
      (hash-set! new-bindings name
        (struct-copy binding-info info [physical physical]))
      (set! new-pool next-pool))

    (define new-body '())
    (define child-pool new-pool)
    (for ([item (in-list (scope-node-body node))])
      (if (scope-node? item)
          (let ([updated-child (traverse item child-pool)])
            (set! new-body (cons updated-child new-body))
            ;; 子作用域释放后，归还其占用的资源
            (set! child-pool
                  (collect-released item child-pool)))
          (set! new-body (cons item new-body))))

    (struct-copy scope-node node
                 [bindings new-bindings]
                 [body (reverse new-body)])))

;; 收集子作用域中应该归还的资源
(define (collect-released child-scope pool)
  (for/fold ([p pool]) ([(name info) (in-hash (scope-node-bindings child-scope))])
    (define lifetime (binding-info-lifetime info))
    (define physical (binding-info-physical info))
    (if (and physical (not (eq? lifetime 'unknown)))
        (set-remove p physical)
        p)))

;; ============================================================
;; Pass 6: 名字消解（虚拟名 → 物理名）
;; ============================================================

;; 返回展平的 item 列表，所有虚拟名已替换为物理名
(define (resolve-names root)
  (let traverse ([node root] [frames '()])
    ;; 构建当前帧：本作用域引入的名字 → 物理名
    (define frame (make-hash))
    (for ([(name info) (in-hash (scope-node-bindings node))])
      (define physical (binding-info-physical info))
      (when physical (hash-set! frame name physical)))

    ;; frame 链：当前帧在前，父帧在后
    (define all-frames (if (hash-empty? frame) frames (cons frame frames)))

    ;; 处理 body：展开子作用域，替换叶子指令中的名字
    (define rev-out '())
    (for ([item (in-list (scope-node-body node))])
      (if (scope-node? item)
          (for ([sub (in-list (traverse item all-frames))])
            (set! rev-out (cons sub rev-out)))
          (set! rev-out (cons (resolve-item item all-frames) rev-out))))
    (reverse rev-out)))

(define (resolve-item item frames)
  (match item
    [(asm-insn mnemonic args)
     (asm-insn mnemonic
       (for/list ([arg (in-list args)])
         (lookup-name arg frames)))]
    [_ item]))

(define (lookup-name sym frames)
  (cond
    [(exact-integer? sym) sym]
    [(reg-num sym) sym]
    [else
     (let loop ([fs frames])
       (cond
         [(null? fs) sym]
         [(hash-ref (car fs) sym #f)]
         [else (loop (cdr fs))]))]))

;; ============================================================
;; Pass 7: 插入回收指令 + 最终展平
;; ============================================================

(define (emit-reclamations root strat)
  (let traverse ([node root])
    (define rev-body '())
    (for ([item (in-list (scope-node-body node))])
      (if (scope-node? item)
          (let* ([inner-body (traverse item)]
                 [reclaim (emit-scope-reclamation item strat)])
            (for ([sub (in-list (append inner-body reclaim))])
              (set! rev-body (cons sub rev-body))))
          (set! rev-body (cons item rev-body))))
    (reverse rev-body)))

(define (emit-scope-reclamation node strat)
  (define items '())
  (for ([(name info) (in-hash (scope-node-bindings node))])
    (define lifetime (binding-info-lifetime info))
    (define escaped? (binding-info-escapes? info))
    (when (and (not escaped?) (not (eq? lifetime 'unknown)))
      (define reclaim ((strategy-reclaimer strat) info node))
      (set! items (append items reclaim))))
  items)

;; ============================================================
;; 预定义策略
;; ============================================================

;; --- 分配器 ---

(define (register-allocator binding scope pool)
  (match (binding-info-spec binding)
    ['get-reg
     (define r (pick-register pool))
     (unless r (error 'scope "out of registers"))
     (cons r (set-add pool r))]
    [(? symbol? r)
     (when (set-member? pool r)
       (error 'scope "register ~a already in use" r))
     (when (eq? r 'x0)
       (error 'scope "cannot bind x0"))
     (cons r (set-add pool r))]
    [_ (error 'scope "invalid register spec: ~a" (binding-info-spec binding))]))

(define (mem-allocator binding scope pool)
  ;; 原型：内存分配暂未实现，返回占位符
  (define name (binding-info-name binding))
  ;; TODO: 从 region 中分配，追踪已用大小
  (cons name pool))

(define (noop-allocator binding scope pool)
  (cons (binding-info-name binding) pool))

;; --- 回收器 ---

(define (register-reclaimer binding scope) '())

(define (stack-mem-reclaimer binding scope)
  (define sz (binding-info-size binding))
  (list (asm-insn 'addi (list 'sp 'sp sz))))

(define (bump-mem-reclaimer binding scope)
  (define rgn (binding-info-region binding))
  (list (asm-insn 'region-reset (list rgn))))

(define (none-reclaimer binding scope) '())

;; --- 组合策略 ---

(define stack-strategy
  (strategy 'stack register-allocator
    (λ (b s)
      (match (binding-info-resource b)
        ['register (register-reclaimer b s)]
        ['mem-block (stack-mem-reclaimer b s)]
        [_ '()]))))

(define bump-strategy
  (strategy 'bump register-allocator
    (λ (b s)
      (match (binding-info-resource b)
        ['register (register-reclaimer b s)]
        ['mem-block (bump-mem-reclaimer b s)]
        [_ '()]))))

(define gc-strategy
  (strategy 'gc register-allocator none-reclaimer))

(define manual-strategy
  (strategy 'manual register-allocator none-reclaimer))

(define (strategy-by-name sym)
  (case sym
    [(stack)  stack-strategy]
    [(bump)   bump-strategy]
    [(gc)     gc-strategy]
    [(manual) manual-strategy]
    [else     (error 'scope "unknown strategy: ~a" sym)]))

;; ============================================================
;; 递归辅助：逃逸分析遍历
;; ============================================================

(define (analyze-all-escapes root)
  (let traverse ([node root])
    (define new-bindings (make-hash))
    (for ([(name info) (in-hash (scope-node-bindings node))])
      (define analyzed
        (escape-analysis info (scope-node-id node) root (scope-node-body node)))
      (hash-set! new-bindings name analyzed))
    (define new-body
      (for/list ([item (in-list (scope-node-body node))])
        (if (scope-node? item) (traverse item) item)))
    (struct-copy scope-node node [bindings new-bindings] [body new-body])))

;; ============================================================
;; 统一遍历：名字消解 + 回收指令（合并为一个 Pass）
;; ============================================================

;; 在单次遍历中完成：名字消解 + 回收指令插入 + 展平
;; 保证回收指令出现在正确的作用域退出点
(define (resolve-and-reclaim root strat [frames '()])
  ;; 构建当前帧
  (define frame (make-hash))
  (for ([(name info) (in-hash (scope-node-bindings root))])
    (define physical (binding-info-physical info))
    (when physical (hash-set! frame name physical)))
  (define all-frames (if (hash-empty? frame) frames (cons frame frames)))

  ;; 处理 body：叶子消解 + 子作用域递归 + 插入回收
  (define rev-out '())
  (for ([item (in-list (scope-node-body root))])
    (if (scope-node? item)
        ;; 子作用域：递归（内部含回收）
        (for ([sub (in-list (resolve-and-reclaim item strat all-frames))])
          (set! rev-out (cons sub rev-out)))
        ;; 叶子：名字消解
        (set! rev-out (cons (resolve-item item all-frames) rev-out))))

  ;; 在 body 末尾追加本作用域的回收指令
  (define reclaim-items (emit-scope-reclamation root strat))
  (for ([item (in-list (reverse reclaim-items))])
    (set! rev-out (cons item rev-out)))

  (reverse rev-out))

;; ============================================================
;; 统一入口
;; ============================================================

;; 完整流水线：items → 分析 → 分配 → 消解+回收 → 展平
;; 返回扁平 asm-item 列表，所有虚拟名已替换为物理名，
;; 回收指令已插入作用域退出点。
(define (analyze-and-resolve items strategy-name)
  (define strat (strategy-by-name strategy-name))

  (define root           (build-scope-tree items))
  (define analyzed       (analyze-all-escapes root))
  (define with-lifetimes (compute-lifetimes analyzed))
  (define allocated      (allocate-resources with-lifetimes strat))

  ;; 名字消解 + 回收指令插入（合并遍历）
  (resolve-and-reclaim allocated strat))

;; 旧接口兼容：apply-scope-rules 保留，但不做分配和消解
(define (apply-scope-rules items strategy-name)
  (analyze-and-resolve items strategy-name))

;; ============================================================
;; 调试辅助
;; ============================================================

(define (print-scope-tree root [indent 0])
  (define pad (make-string indent #\space))
  (printf "~a┌─ scope ~a (~a)~n" pad (scope-node-id root) (scope-node-source root))
  (define binding-lines
    (for/list ([(name info) (in-hash (scope-node-bindings root))])
      (format "~a→~a" name (or (binding-info-physical info) "?"))))
  (unless (null? binding-lines)
    (printf "~a│  bindings: ~a~n" pad binding-lines))
  (for ([item (in-list (scope-node-body root))])
    (if (scope-node? item)
        (print-scope-tree item (+ indent 2))
        (printf "~a│  ~a~n" pad item))))

;; ============================================================
;; 导出
;; ============================================================

(provide
 ;; 统一入口
 analyze-and-resolve
 apply-scope-rules

 ;; AST
 env-let-reg env-let-reg?
 env-let-reg-bindings env-let-reg-body

 ;; 资源池
 register-pool

 ;; 作用域树
 build-scope-tree
 collect-all-bindings
 analyze-all-escapes
 escape-analysis
 compute-lifetimes
 allocate-resources
 resolve-names
 emit-reclamations
 print-scope-tree

 ;; 结构访问器
 scope-node scope-node?
 scope-node-id scope-node-source scope-node-bindings scope-node-body
 binding-info binding-info?
 binding-info-name binding-info-resource binding-info-size
 binding-info-region binding-info-spec binding-info-escapes?
 binding-info-lifetime binding-info-physical
 binding-spec

 ;; 策略
 strategy strategy? strategy-name strategy-allocator strategy-reclaimer
 strategy-by-name
 stack-strategy bump-strategy gc-strategy manual-strategy)
