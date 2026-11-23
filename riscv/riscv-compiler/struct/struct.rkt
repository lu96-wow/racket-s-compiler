#lang racket
;;; struct/struct.rkt
;;;
;;; 结构体布局 + 展开。前端层，不依赖 layout。
;;;
;;; 输入:
;;;   program-items : 代码/模块
;;;   rich-data     : 数据/模块
;;; 输出:
;;;   program-items' rich-data' structs
;;;
;;; 支持的形式:
;;;   (struct (name-chain) (field type) ...)         定义，不占字节
;;;   (struct (name-chain) (align n) (pad n) ...)    内部对齐 / 空洞
;;;   (struct-data (name-chain) (field value) ...)   静态数据实例
;;;   (sizeof name)                                  -> 整数
;;;   (offsetof name field)                          -> 整数
;;;   (struct-load rd base name field)               -> lw/ld/...
;;;   (struct-store base name field rs)              -> sw/sd/...
;;;   (struct-address dst base name field)           -> addi
;;;   (struct-load-far rd base name field tmp)       -> li + add + load
;;;   (struct-store-far base name field rs tmp)      -> li + add + store
;;;   (struct-address-far dst base name field tmp)   -> li + add
;;;
;;; 类型:
;;;   b8 b16 b32 b64 s8 s16 s32 s64 ptr
;;;   (array n type)
;;;   struct-name
;;;
;;; 布局: 自然对齐；字段按声明顺序；支持 (align n) / (pad n)；
;;; 整体 size 向上对齐到最大 align。
;;; 模块: struct 和 label 一样支持 provide / require / prefix-in / rename-in /
;;; re-export；另保留完整链直接可见的兼容路径。
;;; 不处理 bitfield / union / packed / 跨编译单元（分离编译）的 struct。

(require racket/list
         "../sexp.rkt"
         "../modules.rkt"
         "../struct-meta.rkt"
         (only-in "../target.rkt" target-xlen)
         (only-in "../../riscv-asm/base/register.rkt"
                  same-register? zero-register?))

(provide expand-struct-inputs
         layout-extern-struct-decls)

;; ---------------------------------------------------------------------------
;; 内部类型
;; ---------------------------------------------------------------------------

(struct raw-field (name type) #:transparent)
(struct raw-align (n) #:transparent)
(struct raw-pad (n) #:transparent)
(struct raw-def (name scope items) #:transparent)

;; ---------------------------------------------------------------------------
;; 基本形状
;; ---------------------------------------------------------------------------

(define (struct-name-ref? x)
  (or (name? x) (path? x)))

(define (struct-decl? x)
  (and (form? x) (eq? (car x) 'struct) (>= (length x) 2)
       (struct-name-ref? (cadr x))))

(define (struct-data? x)
  (and (form? x) (eq? (car x) 'struct-data) (>= (length x) 2)))

(define (struct-load? x)
  (and (form? x) (eq? (car x) 'struct-load) (= 5 (length x))))

(define (struct-store? x)
  (and (form? x) (eq? (car x) 'struct-store) (= 5 (length x))))

(define (struct-address? x)
  (and (form? x) (eq? (car x) 'struct-address) (= 5 (length x))))

(define (struct-load-far? x)
  (and (form? x) (eq? (car x) 'struct-load-far) (= 6 (length x))))

(define (struct-store-far? x)
  (and (form? x) (eq? (car x) 'struct-store-far) (= 6 (length x))))

(define (struct-address-far? x)
  (and (form? x) (eq? (car x) 'struct-address-far) (= 6 (length x))))

(define (sizeof-form? x)
  (and (form? x) (eq? (car x) 'sizeof) (= 2 (length x))))

(define (offsetof-form? x)
  (and (form? x) (eq? (car x) 'offsetof) (= 3 (length x))))

;; ---------------------------------------------------------------------------
;; 收集定义
;; ---------------------------------------------------------------------------

;; 模块树由 modules.rkt 收集；这里只索引 struct 声明，并记下每个模块
;; 直接声明了哪些 struct 本地链（给 provide * 用）。
(define (index-struct-decl! it scope table own)
  (define name (cadr it))
  (define local (if (path? name) name (list name)))
  (define full (append scope local))
  (when (hash-has-key? table full)
    (error 'struct "struct ~s is defined twice" full))
  (define items
    (for/list ([spec (in-list (cddr it))])
      (cond
        [(and (form? spec) (= 2 (length spec)) (eq? (car spec) 'align))
         (define n (cadr spec))
         (unless (and (exact-positive-integer? n)
                      (zero? (bitwise-and n (sub1 n))))
           (error 'struct "struct align needs a positive power of two: ~e" spec))
         (raw-align n)]
        [(and (form? spec) (= 2 (length spec)) (eq? (car spec) 'pad))
         (define n (cadr spec))
         (unless (exact-nonnegative-integer? n)
           (error 'struct "struct pad needs a non-negative integer: ~e" spec))
         (raw-pad n)]
        [(and (form? spec) (= 2 (length spec))
              (symbol? (car spec)))
         (when (memq (car spec) '(align pad))
           (error 'struct "align/pad are reserved struct directives: ~e" spec))
         (raw-field (car spec) (cadr spec))]
        [else
         (error 'struct "struct item must be (field type), (align n), or (pad n): ~e" spec)])))
  (define names (for/list ([x (in-list items)]
                           #:when (raw-field? x))
                  (raw-field-name x)))
  (unless (= (length names) (length (remove-duplicates names)))
    (error 'struct "struct ~s has duplicate field names" full))
  (hash-set! table full (raw-def full scope items))
  (hash-update! own scope (lambda (l) (append l (list local))) '()))

(define (collect-structs! annotated table own)
  (for ([entry (in-list annotated)])
    (define scope (car entry))
    (define it (cdr entry))
    (when (struct-decl? it)
      (index-struct-decl! it scope table own))))

;; ---------------------------------------------------------------------------
;; 类型 / 布局
;; ---------------------------------------------------------------------------

(define (xlen-bytes target)
  (if (eq? (target-xlen target) 'rv32) 4 8))

(define (scalar-size-align t xlen)
  (case t
    [(b8 s8) (values 1 1)]
    [(b16 s16) (values 2 2)]
    [(b32 s32) (values 4 4)]
    [(b64 s64) (values 8 8)]
    [(ptr) (values xlen xlen)]
    [else (error 'struct "not a scalar type: ~e" t)]))

(define (align-up n align)
  (* align (quotient (+ n (sub1 align)) align)))

(define (resolve-struct-name table scope ref imports)
  (define local
    (cond
      [(path? ref) ref]
      [(name? ref) (list ref)]
      [else (error 'struct "struct name must be a name or chain: ~e" ref)]))
  (or ;; require 绑定：由内到外
      (for/or ([p (in-list (ancestors-and-self scope))])
        (define hit (assoc local (hash-ref imports p '())))
        (and hit (cdr hit)))
      ;; 本地 / 祖先 struct：原有的词法路径
      (for/or ([p (in-list (ancestors-and-self scope))])
        (define full (append p local))
        (and (hash-ref table full #f) full))
      (error 'struct "undefined struct ~s" ref)))

(define (resolve-type type scope table imports)
  (cond
    [(scalar-type? type) type]
    [(and (form? type) (eq? (car type) 'array) (= 3 (length type))
          (exact-nonnegative-integer? (cadr type)))
     (list 'array (cadr type) (resolve-type (caddr type) scope table imports))]
    [(or (symbol? type) (path? type))
     (list 'struct-ref (resolve-struct-name table scope type imports))]
    [else
     (error 'struct "unknown struct field type: ~e" type)]))

(define (type-size-align type table defs xlen visiting imports)
  (cond
    [(scalar-type? type)
     (scalar-size-align type xlen)]
    [(and (form? type) (eq? (car type) 'array))
     (define elem (caddr type))
     (define-values (es ea)
       (type-size-align elem table defs xlen visiting imports))
     (values (* (cadr type) es) ea)]
    [(and (form? type) (eq? (car type) 'struct-ref))
     (define d (compute-struct (cadr type) table defs xlen visiting imports))
     (values (sdef-size d) (sdef-align d))]
    [else
     (error 'struct "bad resolved struct type: ~e" type)]))

(define (compute-struct full table defs xlen visiting imports)
  (cond
    [(hash-ref defs full #f) (hash-ref defs full)]
    [(member full visiting)
     (error 'struct "recursive struct definition: ~e" (reverse (cons full visiting)))]
    [else
     (define raw (or (hash-ref table full #f)
                     (error 'struct "undefined struct ~s" full)))
     (define cursor 0)
     (define max-align 1)
     (define fields '())
     (define items '())
     (define padding '())
     (for ([spec (in-list (raw-def-items raw))])
       (cond
         [(raw-field? spec)
          (define type (resolve-type (raw-field-type spec) (raw-def-scope raw) table imports))
          (define-values (sz al)
            (type-size-align type table defs xlen (cons full visiting) imports))
          (set! cursor (align-up cursor al))
          (define f (field (raw-field-name spec) type cursor sz al))
          (set! fields (cons f fields))
          (set! items (cons f items))
          (set! cursor (+ cursor sz))
          (set! max-align (max max-align al))]
         [(raw-align? spec)
          (define old cursor)
          (define n (raw-align-n spec))
          (set! cursor (align-up cursor n))
          (define p (- cursor old))
          (define it (align-item n old p))
          (set! padding (cons it padding))
          (set! items (cons it items))
          (set! max-align (max max-align n))]
         [(raw-pad? spec)
          (define old cursor)
          (define n (raw-pad-n spec))
          (set! cursor (+ cursor n))
          (define it (pad-item n old n))
          (set! padding (cons it padding))
          (set! items (cons it items))]
         [else (error 'struct "bad struct item: ~e" spec)]))
     (define d (sdef full
                     (reverse fields)
                     (reverse items)
                     (reverse padding)
                     (align-up cursor max-align)
                     max-align))
     (hash-set! defs full d)
     d]))

(define (chain-string chain) (format "~a" chain))

(define (compute-all table xlen imports [initial-defs (make-hash)])
  (define defs initial-defs)
  (for ([full (in-list (sort (hash-keys table)
                             (lambda (a b) (string<? (chain-string a)
                                                      (chain-string b)))))])
    (compute-struct full table defs xlen '() imports))
  defs)

;; ---------------------------------------------------------------------------
;; 查找
;; ---------------------------------------------------------------------------

(define (def-of table defs ref scope imports)
  (define full (resolve-struct-name table scope ref imports))
  (hash-ref defs full))

(define (field-of d name)
  (or (findf (lambda (f) (eq? (field-name f) name)) (sdef-fields d))
      (error 'struct "struct ~s has no field ~s" (sdef-name d) name)))

(define (scalar-width type xlen)
  (case type
    [(b8 s8) 1]
    [(b16 s16) 2]
    [(b32 s32) 4]
    [(b64 s64) 8]
    [(ptr) xlen]
    [else (error 'struct "field is not scalar: ~e" type)]))

(define (scalar-type?/resolved type)
  (and (symbol? type) (scalar-type? type)))

;; ---------------------------------------------------------------------------
;; 静态数据展开
;; ---------------------------------------------------------------------------

(define (init-fields d inits)
  (define h (make-hash))
  (for ([p (in-list inits)])
    (unless (and (form? p) (>= (length p) 1) (symbol? (car p)))
      (error 'struct "struct initializer must be (field value ...): ~e" p))
    (field-of d (car p))
    (when (hash-has-key? h (car p))
      (error 'struct "duplicate field initializer: ~e" (car p)))
    (hash-set! h (car p) (cdr p)))
  h)

(define (pad-if n)
  (if (zero? n) '() (list (list 'pad n))))

(define (expand-static-struct d inits scope table defs target imports)
  (define ih (init-fields d inits))
  (define items
    (if (> (sdef-align d) 1)
        (list (list 'align (sdef-align d)))
        '()))
  (define cursor 0)
  (for ([item (in-list (sdef-items d))])
    (cond
      [(field? item)
       (define off (field-offset item))
       (when (> off cursor)
         (set! items (append items (pad-if (- off cursor))))
         (set! cursor off))
       (define hit (hash-ref ih (field-name item) #f))
       (define f-items
         (if hit
             (expand-static-value (field-type item) hit scope table defs target imports)
             (pad-if (field-size item))))
       (set! items (append items f-items))
       (set! cursor (+ off (field-size item)))]
      [(or (align-item? item) (pad-item? item))
       (define off
         (if (align-item? item)
             (align-item-offset item)
             (pad-item-offset item)))
       (define sz
         (if (align-item? item)
             (align-item-size item)
             (pad-item-size item)))
       (when (> off cursor)
         (set! items (append items (pad-if (- off cursor))))
         (set! cursor off))
       (set! items (append items (pad-if sz)))
       (set! cursor (+ off sz))]
      [else (error 'struct "bad struct layout item: ~e" item)]))
  (append items (pad-if (- (sdef-size d) cursor))))

(define (expand-static-value type vals scope table defs target imports)
  (cond
    [(scalar-type?/resolved type)
     (unless (= 1 (length vals))
       (error 'struct "scalar field needs exactly one initializer: ~e" vals))
     (list (list 'value (scalar-width type (xlen-bytes target))
                 (expand-expr (car vals) scope table defs imports)))]
    [(and (form? type) (eq? (car type) 'array))
     (expand-static-array type vals scope table defs target imports)]
    [(and (form? type) (eq? (car type) 'struct-ref))
     (define d (hash-ref defs (cadr type)))
     (unless (and (list? vals)
                  (andmap (lambda (p) (and (form? p) (>= (length p) 1) (symbol? (car p))))
                          vals))
       (error 'struct "nested struct initializer must be (field value ...): ~e" vals))
     (expand-static-struct d vals scope table defs target imports)]
    [else
     (error 'struct "unknown field type: ~e" type)]))

(define (expand-static-array type vals scope table defs target imports)
  (define n (cadr type))
  (define elem (caddr type))
  (define elements
    (if (and (= 1 (length vals))
             (form? (car vals))
             (eq? (car (car vals)) 'array))
        (cdr (car vals))
        vals))
  (when (> (length elements) n)
    (error 'struct "too many array initializers: ~e" elements))
  (define (element-vals v)
    (cond
      [(scalar-type?/resolved elem) (list v)]
      [(and (form? elem) (eq? (car elem) 'struct-ref)) v]
      [(and (form? elem) (eq? (car elem) 'array)) (list v)]
      [else (list v)]))
  (define values (for/list ([v (in-list elements)])
                   (expand-static-value elem (element-vals v) scope table defs target imports)))
  (define-values (es _ea)
    (type-size-align elem table defs (xlen-bytes target) '() imports))
  (append (append* values)
          (pad-if (* (- n (length elements)) es))))

;; ---------------------------------------------------------------------------
;; 编译期整数
;; ---------------------------------------------------------------------------

(define (sizeof-value form scope table defs imports)
  (define d (def-of table defs (cadr form) scope imports))
  (sdef-size d))

(define (offsetof-value form scope table defs imports)
  (define name (cadr form))
  (define field-name (caddr form))
  (unless (symbol? field-name)
    (error 'struct "offsetof field must be a symbol: ~e" form))
  (define d (def-of table defs name scope imports))
  (field-offset (field-of d field-name)))

;; ---------------------------------------------------------------------------
;; 表达式递归：只替换 sizeof / offsetof
;; ---------------------------------------------------------------------------

(define (expand-expr x scope table defs imports)
  (cond
    [(sizeof-form? x) (sizeof-value x scope table defs imports)]
    [(offsetof-form? x) (offsetof-value x scope table defs imports)]
    [(form? x) (for/list ([y (in-list x)]) (expand-expr y scope table defs imports))]
    [else x]))

;; ---------------------------------------------------------------------------
;; 动态访问
;; ---------------------------------------------------------------------------

(define (fits-s12? n) (<= -2048 n 2047))

(define (load-mnemonic type target)
  (case type
    [(b8) 'lbu]
    [(s8) 'lb]
    [(b16) 'lhu]
    [(s16) 'lh]
    [(b32) (if (eq? (target-xlen target) 'rv32) 'lw 'lwu)]
    [(s32) 'lw]
    [(b64 s64) (if (eq? (target-xlen target) 'rv32)
                   (error 'struct "b64/s64 field is not available on RV32")
                   'ld)]
    [(ptr) (if (eq? (target-xlen target) 'rv32) 'lw 'ld)]
    [else (error 'struct "field is not scalar: ~e" type)]))

(define (store-mnemonic type target)
  (case type
    [(b8 s8) 'sb]
    [(b16 s16) 'sh]
    [(b32 s32) 'sw]
    [(b64 s64) (if (eq? (target-xlen target) 'rv32)
                   (error 'struct "b64/s64 field is not available on RV32")
                   'sd)]
    [(ptr) (if (eq? (target-xlen target) 'rv32) 'sw 'sd)]
    [else (error 'struct "field is not scalar: ~e" type)]))

(define (ensure-scalar-field f)
  (unless (scalar-type?/resolved (field-type f))
    (error 'struct "field ~s is aggregate; use struct-address"
           (field-name f))))

(define (ensure-tmp who tmp base . others)
  (when (zero-register? tmp)
    (error who "scratch must not be x0"))
  (when (same-register? tmp base)
    (error who "scratch must differ from base"))
  (for ([r (in-list others)])
    (when (same-register? tmp r)
      (error who "scratch must differ from ~a" r))))

(define (struct-load-short it scope table defs target imports)
  (define rd (cadr it))
  (define base (caddr it))
  (define d (def-of table defs (cadddr it) scope imports))
  (define f (field-of d (car (cddddr it))))
  (ensure-scalar-field f)
  (unless (fits-s12? (field-offset f))
    (error 'struct "field ~s offset ~a exceeds simm12; use struct-load-far"
           (field-name f) (field-offset f)))
  (list (load-mnemonic (field-type f) target) rd base (field-offset f)))

(define (struct-store-short it scope table defs target imports)
  (define base (cadr it))
  (define d (def-of table defs (caddr it) scope imports))
  (define f (field-of d (cadddr it)))
  (define rs (car (cddddr it)))
  (ensure-scalar-field f)
  (unless (fits-s12? (field-offset f))
    (error 'struct "field ~s offset ~a exceeds simm12; use struct-store-far"
           (field-name f) (field-offset f)))
  (list (store-mnemonic (field-type f) target) (field-offset f) base rs))

(define (struct-address-short it scope table defs imports)
  (define dst (cadr it))
  (define base (caddr it))
  (define d (def-of table defs (cadddr it) scope imports))
  (define f (field-of d (car (cddddr it))))
  (unless (fits-s12? (field-offset f))
    (error 'struct "field ~s offset ~a exceeds simm12; use struct-address-far"
           (field-name f) (field-offset f)))
  (list 'addi dst base (field-offset f)))

(define (struct-load-far it scope table defs target imports)
  (define rd (cadr it))
  (define base (caddr it))
  (define d (def-of table defs (cadddr it) scope imports))
  (define f (field-of d (car (cddddr it))))
  (define tmp (list-ref it 5))
  (ensure-scalar-field f)
  (ensure-tmp 'struct-load-far tmp base)
  (list (list 'li tmp (field-offset f))
        (list 'add tmp base tmp)
        (list (load-mnemonic (field-type f) target) rd tmp 0)))

(define (struct-store-far it scope table defs target imports)
  (define base (cadr it))
  (define d (def-of table defs (caddr it) scope imports))
  (define f (field-of d (cadddr it)))
  (define rs (list-ref it 4))
  (define tmp (list-ref it 5))
  (ensure-scalar-field f)
  (ensure-tmp 'struct-store-far tmp base rs)
  (list (list 'li tmp (field-offset f))
        (list 'add tmp base tmp)
        (list (store-mnemonic (field-type f) target) 0 tmp rs)))

(define (struct-address-far it scope table defs imports)
  (define dst (cadr it))
  (define base (caddr it))
  (define d (def-of table defs (cadddr it) scope imports))
  (define f (field-of d (car (cddddr it))))
  (define tmp (list-ref it 5))
  (ensure-tmp 'struct-address-far tmp base)
  (list (list 'li tmp (field-offset f))
        (list 'add dst base tmp)))

;; ---------------------------------------------------------------------------
;; 遍历展开
;; ---------------------------------------------------------------------------

(define (expand-item it scope table defs target imports)
  (cond
    [(struct-decl? it) '()]
    [(or (module-form? it) (clause-form? it 'provide) (clause-form? it 'require))
     (if (module-form? it)
         (list (cons 'module
                     (cons (cadr it)
                           (expand-items (cddr it)
                                         (append scope (list (cadr it)))
                                         table defs target imports))))
         ;; provide / require 是 flatten 的子句；这里原样保留。
         (list it))]
    [(struct-data? it)
     (define d (def-of table defs (cadr it) scope imports))
     (expand-static-struct d (cddr it) scope table defs target imports)]
    [(struct-load? it) (list (struct-load-short it scope table defs target imports))]
    [(struct-store? it) (list (struct-store-short it scope table defs target imports))]
    [(struct-address? it) (list (struct-address-short it scope table defs imports))]
    [(struct-load-far? it) (list (struct-load-far it scope table defs target imports))]
    [(struct-store-far? it) (list (struct-store-far it scope table defs target imports))]
    [(struct-address-far? it) (list (struct-address-far it scope table defs imports))]
    [else (list (expand-expr it scope table defs imports))]))

(define (expand-items items scope table defs target imports)
  (append* (for/list ([it (in-list items)])
             (expand-item it scope table defs target imports))))

;; ---------------------------------------------------------------------------
;; 导出元数据
;; ---------------------------------------------------------------------------

(define (structs->sexp defs)
  (map sdef->sexp
       (sort (hash-values defs)
             (lambda (a b)
               (string<? (chain-string (sdef-name a))
                         (chain-string (sdef-name b)))))))

;; ---------------------------------------------------------------------------
;; 入口
;; ---------------------------------------------------------------------------

;; ---------------------------------------------------------------------------
;; 外部 struct（跨编译单元）
;;
;; 输入就是上一份 build 的 (structs …) 元数据。它已经是算好的布局，所以直接
;; 装进 defs，不再重新推导 offset / size / align。名字按完整链可见。
;; ---------------------------------------------------------------------------

(define (install-extern-structs! table defs extern-defs)
  (for ([d (in-list extern-defs)])
    (define name (sdef-name d))
    (cond
      [(hash-ref defs name #f)
       (unless (equal? (hash-ref defs name) d)
         (error 'struct "外部 struct ~s 有两份不同的定义" name))]
      [(hash-has-key? table name)
       (error 'struct "struct ~s 同时由本单元和外部定义" name)]
      [else
       (hash-set! table name (raw-def name '() '()))
       (hash-set! defs name d)])))

(define (parse-extern-structs datum)
  (map parse-sdef (extern-struct-defs datum)))

;; ---------------------------------------------------------------------------
;; 入口
;; ---------------------------------------------------------------------------

;; 把 extern-units 里的布局无关 struct 声明按当前 target 重新算成 struct-def 元数据。
(define (layout-extern-struct-decls target decls)
  (define table (make-hash))
  (define own (make-hash))
  (for ([d (in-list decls)])
    (index-struct-decl! d '() table own))
  (define defs (compute-all table (xlen-bytes target) (make-hash)))
  (structs->sexp defs))

(define (expand-struct-inputs target program-items rich-data
                              [extern-structs '()]
                              [extern-struct-provides '()])
  (define table (make-hash))
  (define modules (make-hash))
  (define own (make-hash))
  (define annotated
    (collect-modules (append program-items rich-data) '() modules))
  (collect-structs! annotated table own)
  (define extern-provides
    (parse-extern-provides extern-struct-provides 'struct-provides))
  (define-values (imports provides _unresolved)
    (resolve-modules modules
                     #:declarations table
                     #:own own
                     #:extern-provides extern-provides
                     ;; require 可能是给 label 层用的；这里不能替它判未知模块。
                     #:allow-unknown-modules? #t))
  (define local-struct-names (make-hash))
  (for ([name (in-hash-keys table)]) (hash-set! local-struct-names name #t))
  (define seeded-defs (make-hash))
  (install-extern-structs! table seeded-defs (parse-extern-structs extern-structs))
  (define defs (compute-all table (xlen-bytes target) imports seeded-defs))
  (values (expand-items program-items '() table defs target imports)
          (expand-items rich-data '() table defs target imports)
          ;; unit 只描述本单元；外部 struct 由 extern-units 带进来。
          (structs->sexp
           (for/hash ([(name d) (in-hash defs)]
                      #:when (hash-ref local-struct-names name #f))
             (values name d)))
          (provides->sexp provides)))
