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
;;; 不处理 bitfield / union / packed / 跨模块 require 的 struct。

(require racket/list
         "../sexp.rkt"
         (only-in "../target.rkt" target-xlen)
         (only-in "../../riscv-asm/base/register.rkt"
                  same-register? zero-register?))

(provide expand-struct-inputs)

;; ---------------------------------------------------------------------------
;; 内部类型
;; ---------------------------------------------------------------------------

(struct raw-field (name type) #:transparent)
(struct raw-align (n) #:transparent)
(struct raw-pad (n) #:transparent)
(struct raw-def (name scope items) #:transparent)

(struct field (name type offset size align) #:transparent)
(struct align-item (n offset size) #:transparent)
(struct pad-item (n offset size) #:transparent)
(struct sdef (name fields items padding size align) #:transparent)

;; ---------------------------------------------------------------------------
;; 基本形状
;; ---------------------------------------------------------------------------

(define (module-form? x) (and (form? x) (eq? (car x) 'module)))

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

(define (collect-structs! items scope table)
  (for ([it (in-list items)])
    (cond
      [(module-form? it)
       (unless (and (>= (length it) 2) (name? (cadr it)))
         (error 'struct "module needs a name: ~e" it))
       (collect-structs! (cddr it) (append scope (list (cadr it))) table)]
      [(struct-decl? it)
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
       (hash-set! table full (raw-def full scope items))]
      [else (void)])))

;; ---------------------------------------------------------------------------
;; 类型 / 布局
;; ---------------------------------------------------------------------------

(define (scalar-type? t)
  (memq t '(b8 b16 b32 b64 s8 s16 s32 s64 ptr)))

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

(define (ancestors-and-self scope)
  (let loop ([s scope] [acc '()])
    (cond
      [(null? s) (reverse (cons '() acc))]
      [else (loop (drop-right s 1) (cons s acc))])))

(define (resolve-struct-name table scope ref)
  (define local
    (cond
      [(path? ref) ref]
      [(name? ref) (list ref)]
      [else (error 'struct "struct name must be a name or chain: ~e" ref)]))
  (or (for/or ([p (in-list (ancestors-and-self scope))])
        (define full (append p local))
        (and (hash-ref table full #f) full))
      (error 'struct "undefined struct ~s" ref)))

(define (resolve-type type scope table)
  (cond
    [(scalar-type? type) type]
    [(and (form? type) (eq? (car type) 'array) (= 3 (length type))
          (exact-nonnegative-integer? (cadr type)))
     (list 'array (cadr type) (resolve-type (caddr type) scope table))]
    [(or (symbol? type) (path? type))
     (list 'struct-ref (resolve-struct-name table scope type))]
    [else
     (error 'struct "unknown struct field type: ~e" type)]))

(define (type-size-align type table defs xlen visiting)
  (cond
    [(scalar-type? type)
     (scalar-size-align type xlen)]
    [(and (form? type) (eq? (car type) 'array))
     (define elem (caddr type))
     (define-values (es ea)
       (type-size-align elem table defs xlen visiting))
     (values (* (cadr type) es) ea)]
    [(and (form? type) (eq? (car type) 'struct-ref))
     (define d (compute-struct (cadr type) table defs xlen visiting))
     (values (sdef-size d) (sdef-align d))]
    [else
     (error 'struct "bad resolved struct type: ~e" type)]))

(define (compute-struct full table defs xlen visiting)
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
          (define type (resolve-type (raw-field-type spec) (raw-def-scope raw) table))
          (define-values (sz al)
            (type-size-align type table defs xlen (cons full visiting)))
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

(define (compute-all table xlen)
  (define defs (make-hash))
  (for ([full (in-list (sort (hash-keys table)
                             (lambda (a b) (string<? (chain-string a)
                                                      (chain-string b)))))])
    (compute-struct full table defs xlen '()))
  defs)

;; ---------------------------------------------------------------------------
;; 查找
;; ---------------------------------------------------------------------------

(define (def-of table defs ref scope)
  (define full (resolve-struct-name table scope ref))
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

(define (expand-static-struct d inits scope table defs target)
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
             (expand-static-value (field-type item) hit scope table defs target)
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

(define (expand-static-value type vals scope table defs target)
  (cond
    [(scalar-type?/resolved type)
     (unless (= 1 (length vals))
       (error 'struct "scalar field needs exactly one initializer: ~e" vals))
     (list (list 'value (scalar-width type (xlen-bytes target))
                 (expand-expr (car vals) scope table defs)))]
    [(and (form? type) (eq? (car type) 'array))
     (expand-static-array type vals scope table defs target)]
    [(and (form? type) (eq? (car type) 'struct-ref))
     (define d (hash-ref defs (cadr type)))
     (unless (and (list? vals)
                  (andmap (lambda (p) (and (form? p) (>= (length p) 1) (symbol? (car p))))
                          vals))
       (error 'struct "nested struct initializer must be (field value ...): ~e" vals))
     (expand-static-struct d vals scope table defs target)]
    [else
     (error 'struct "unknown field type: ~e" type)]))

(define (expand-static-array type vals scope table defs target)
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
                   (expand-static-value elem (element-vals v) scope table defs target)))
  (define-values (es _ea)
    (type-size-align elem table defs (xlen-bytes target) '()))
  (append (append* values)
          (pad-if (* (- n (length elements)) es))))

;; ---------------------------------------------------------------------------
;; 编译期整数
;; ---------------------------------------------------------------------------

(define (sizeof-value form scope table defs)
  (define d (def-of table defs (cadr form) scope))
  (sdef-size d))

(define (offsetof-value form scope table defs)
  (define name (cadr form))
  (define field-name (caddr form))
  (unless (symbol? field-name)
    (error 'struct "offsetof field must be a symbol: ~e" form))
  (define d (def-of table defs name scope))
  (field-offset (field-of d field-name)))

;; ---------------------------------------------------------------------------
;; 表达式递归：只替换 sizeof / offsetof
;; ---------------------------------------------------------------------------

(define (expand-expr x scope table defs)
  (cond
    [(sizeof-form? x) (sizeof-value x scope table defs)]
    [(offsetof-form? x) (offsetof-value x scope table defs)]
    [(form? x) (for/list ([y (in-list x)]) (expand-expr y scope table defs))]
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

(define (struct-load-short it scope table defs target)
  (define rd (cadr it))
  (define base (caddr it))
  (define d (def-of table defs (cadddr it) scope))
  (define f (field-of d (car (cddddr it))))
  (ensure-scalar-field f)
  (unless (fits-s12? (field-offset f))
    (error 'struct "field ~s offset ~a exceeds simm12; use struct-load-far"
           (field-name f) (field-offset f)))
  (list (load-mnemonic (field-type f) target) rd base (field-offset f)))

(define (struct-store-short it scope table defs target)
  (define base (cadr it))
  (define d (def-of table defs (caddr it) scope))
  (define f (field-of d (cadddr it)))
  (define rs (car (cddddr it)))
  (ensure-scalar-field f)
  (unless (fits-s12? (field-offset f))
    (error 'struct "field ~s offset ~a exceeds simm12; use struct-store-far"
           (field-name f) (field-offset f)))
  (list (store-mnemonic (field-type f) target) (field-offset f) base rs))

(define (struct-address-short it scope table defs)
  (define dst (cadr it))
  (define base (caddr it))
  (define d (def-of table defs (cadddr it) scope))
  (define f (field-of d (car (cddddr it))))
  (unless (fits-s12? (field-offset f))
    (error 'struct "field ~s offset ~a exceeds simm12; use struct-address-far"
           (field-name f) (field-offset f)))
  (list 'addi dst base (field-offset f)))

(define (struct-load-far it scope table defs target)
  (define rd (cadr it))
  (define base (caddr it))
  (define d (def-of table defs (cadddr it) scope))
  (define f (field-of d (car (cddddr it))))
  (define tmp (list-ref it 5))
  (ensure-scalar-field f)
  (ensure-tmp 'struct-load-far tmp base)
  (list (list 'li tmp (field-offset f))
        (list 'add tmp base tmp)
        (list (load-mnemonic (field-type f) target) rd tmp 0)))

(define (struct-store-far it scope table defs target)
  (define base (cadr it))
  (define d (def-of table defs (caddr it) scope))
  (define f (field-of d (cadddr it)))
  (define rs (list-ref it 4))
  (define tmp (list-ref it 5))
  (ensure-scalar-field f)
  (ensure-tmp 'struct-store-far tmp base rs)
  (list (list 'li tmp (field-offset f))
        (list 'add tmp base tmp)
        (list (store-mnemonic (field-type f) target) 0 tmp rs)))

(define (struct-address-far it scope table defs)
  (define dst (cadr it))
  (define base (caddr it))
  (define d (def-of table defs (cadddr it) scope))
  (define f (field-of d (car (cddddr it))))
  (define tmp (list-ref it 5))
  (ensure-tmp 'struct-address-far tmp base)
  (list (list 'li tmp (field-offset f))
        (list 'add dst base tmp)))

;; ---------------------------------------------------------------------------
;; 遍历展开
;; ---------------------------------------------------------------------------

(define (expand-item it scope table defs target)
  (cond
    [(struct-decl? it) '()]
    [(module-form? it)
     (list (cons 'module
                 (cons (cadr it)
                       (expand-items (cddr it)
                                     (append scope (list (cadr it)))
                                     table defs target))))]
    [(struct-data? it)
     (define d (def-of table defs (cadr it) scope))
     (expand-static-struct d (cddr it) scope table defs target)]
    [(struct-load? it) (list (struct-load-short it scope table defs target))]
    [(struct-store? it) (list (struct-store-short it scope table defs target))]
    [(struct-address? it) (list (struct-address-short it scope table defs))]
    [(struct-load-far? it) (list (struct-load-far it scope table defs target))]
    [(struct-store-far? it) (list (struct-store-far it scope table defs target))]
    [(struct-address-far? it) (list (struct-address-far it scope table defs))]
    [else (list (expand-expr it scope table defs))]))

(define (expand-items items scope table defs target)
  (append* (for/list ([it (in-list items)])
             (expand-item it scope table defs target))))

;; ---------------------------------------------------------------------------
;; 导出元数据
;; ---------------------------------------------------------------------------

(define (type->sexp t)
  (cond
    [(scalar-type? t) t]
    [(and (form? t) (eq? (car t) 'array))
     (list 'array (cadr t) (type->sexp (caddr t)))]
    [(and (form? t) (eq? (car t) 'struct-ref))
     (list 'struct-ref (cadr t))]
    [else (error 'struct "bad type in metadata: ~e" t)]))

(define (field->sexp f)
  (list 'field
        (list 'name (field-name f))
        (list 'type (type->sexp (field-type f)))
        (list 'offset (field-offset f))
        (list 'size (field-size f))
        (list 'align (field-align f))))

(define (padding->sexp p)
  (cond
    [(align-item? p)
     (list 'align
           (list 'n (align-item-n p))
           (list 'offset (align-item-offset p))
           (list 'size (align-item-size p)))]
    [(pad-item? p)
     (list 'pad
           (list 'n (pad-item-n p))
           (list 'offset (pad-item-offset p))
           (list 'size (pad-item-size p)))]
    [else (error 'struct "bad padding item: ~e" p)]))

(define (sdef->sexp d)
  (list 'struct-def
        (list 'name (sdef-name d))
        (list 'size (sdef-size d))
        (list 'align (sdef-align d))
        (cons 'fields (map field->sexp (sdef-fields d)))
        (cons 'padding (map padding->sexp (sdef-padding d)))))

(define (structs->sexp defs)
  (map sdef->sexp
       (sort (hash-values defs)
             (lambda (a b)
               (string<? (chain-string (sdef-name a))
                         (chain-string (sdef-name b)))))))

;; ---------------------------------------------------------------------------
;; 入口
;; ---------------------------------------------------------------------------

(define (expand-struct-inputs target program-items rich-data)
  (define table (make-hash))
  (collect-structs! program-items '() table)
  (collect-structs! rich-data '() table)
  (define defs (compute-all table (xlen-bytes target)))
  (values (expand-items program-items '() table defs target)
          (expand-items rich-data '() table defs target)
          (structs->sexp defs)))
