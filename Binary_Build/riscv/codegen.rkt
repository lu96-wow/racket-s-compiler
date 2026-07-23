#lang racket

(require racket/string
         "parse/main.rkt")

;; ============================================================
;; 基础代码生成
;; ============================================================

(define (fixed-field->code ff)
  (format "(bit-range-fixed ~a ~a ~a)"
          (fixed-field-high ff)
          (fixed-field-low ff)
          (fixed-field-value ff)))

(define (gen-instruction-code idef)
  (define args
    (append (instruction-def-operands idef)
            (map fixed-field->code (instruction-def-fixed-fields idef))))
  (format "(define ~a (make-instruction ~a))"
          (instruction-def-name idef)
          (string-join args " ")))

(define (gen-instruction-file-content defs)
  (string-join
   (append
    (list "#lang racket"
          "(require \"../../base.rkt\""
          "         \"../base_range.rkt\""
          "         \"../register.rkt\")"
          "")
    (map gen-instruction-code defs)
    (list ""
          "(provide (all-defined-out))"
          ""))
   "\n"))

;; ============================================================
;; 操作数类型分类
;; ============================================================

;; 根据操作数名称推断类型: 'reg | 'imm | 'csr | 'vec
(define (classify-operand name)
  (cond
    ;; 标准寄存器
    [(regexp-match? #rx"^(rd|rs[1-4])$" name) 'reg]
    ;; 约束寄存器
    [(regexp-match? #rx"^(rd_n[02]|rs[12]_n0|rd_rs1_n0|rd_rs1_p|rs[12]_p|rd_p)$" name) 'reg]
    ;; 压缩指令寄存器
    [(regexp-match? #rx"^c_(rs[12]|sreg[12])(_n0)?$" name) 'reg]
    ;; CSR
    [(equal? name "csr") 'csr]
    ;; 向量寄存器
    [(regexp-match? #rx"^(vd|vs[1-3]|vm)$" name) 'vec]
    ;; 向量寄存器列表 (Zcmp push/pop)
    [(equal? name "c_rlist") 'vec]
    ;; 其余全是立即数
    [else 'imm]))

;; ============================================================
;; 指令宽度判定
;; ============================================================

;; 根据扩展类型符号判断指令宽度 (16 或 32)
(define (extension-width type-sym)
  (define s (symbol->string type-sym))
  (if (or (member type-sym '(rv_c rv32_c rv64_c rv_zcb))
          (regexp-match? #rx"^(rv_c_|rv32_c_|rv64_c_|rv_zcm)" s))
      16
      32))

;; ============================================================
;; 汇编格式字符串
;; ============================================================

(define (asm-format name operands)
  (if (null? operands)
      name
      (format "~a ~a" name (string-join operands ", "))))

;; ============================================================
;; 指令信息文件 (字段哈希 + 元数据)
;; ============================================================

(define (gen-instruction-info-file-content type-sym defs)
  (define all-fields
    (let loop ([ds defs] [seen '()])
      (if (null? ds)
          (reverse seen)
          (loop (cdr ds)
                (for/fold ([s seen])
                          ([f (in-list (instruction-def-operands (car ds)))])
                  (if (member f s) s (cons f s)))))))

  (define (index-of lst elem)
    (let loop ([l lst] [i 0])
      (cond [(null? l) #f]
            [(equal? (car l) elem) i]
            [else (loop (cdr l) (+ i 1))])))

  (define width (extension-width type-sym))

  ;; ── 原有: 字段哈希 ──
  (define field-hash-defs
    (for/list ([field (in-list all-fields)])
      (define bindings
        (for/list ([idef (in-list defs)]
                    #:when (index-of (instruction-def-operands idef) field))
          (format "(~a . ~a)"
                  (instruction-def-name idef)
                  (+ 1 (index-of (instruction-def-operands idef) field)))))
      (define var-name (format "~a-~a" type-sym field))
      (if (null? bindings)
          (format "(define ~a (make-immutable-hash '()))" var-name)
          (string-join
           (append (list (format "(define ~a" var-name)
                         "  (make-immutable-hash"
                         "    '(")
                   (map (λ (b) (format "      ~a" b)) bindings)
                   (list "    )))"))
           "\n"))))

  ;; ── 原有: 字段列表 ──
  (define fields-var (format "~a-fields" type-sym))
  (define fields-def
    (if (null? all-fields)
        (format "(define ~a '())" fields-var)
        (format "(define ~a '(~a))" fields-var
                (string-join all-fields " "))))

  ;; ── 新增: 参数个数 ──
  (define param-count-var (format "~a-param-count" type-sym))
  (define param-count-bindings
    (for/list ([idef (in-list defs)])
      (format "(~a . ~a)" (instruction-def-name idef)
              (length (instruction-def-operands idef)))))
  (define param-count-def
    (if (null? param-count-bindings)
        (format "(define ~a (make-immutable-hash '()))" param-count-var)
        (string-join
         (append (list (format "(define ~a" param-count-var)
                       "  (make-immutable-hash"
                       "    '(")
                 (map (λ (b) (format "      ~a" b)) param-count-bindings)
                 (list "    )))"))
         "\n")))

  ;; ── 新增: 操作数列表 ──
  (define operands-var (format "~a-operands" type-sym))
  (define operands-bindings
    (for/list ([idef (in-list defs)])
      (format "(~a . (~a))" (instruction-def-name idef)
              (string-join (instruction-def-operands idef) " "))))
  (define operands-def
    (if (null? operands-bindings)
        (format "(define ~a (make-immutable-hash '()))" operands-var)
        (string-join
         (append (list (format "(define ~a" operands-var)
                       "  (make-immutable-hash"
                       "    '(")
                 (map (λ (b) (format "      ~a" b)) operands-bindings)
                 (list "    )))"))
         "\n")))

  ;; ── 新增: 汇编格式 ──
  (define asm-var (format "~a-asm" type-sym))
  (define asm-bindings
    (for/list ([idef (in-list defs)])
      (format "(~a . ~s)" (instruction-def-name idef)
              (asm-format (instruction-def-name idef)
                          (instruction-def-operands idef)))))
  (define asm-def
    (if (null? asm-bindings)
        (format "(define ~a (make-immutable-hash '()))" asm-var)
        (string-join
         (append (list (format "(define ~a" asm-var)
                       "  (make-immutable-hash"
                       "    '(")
                 (map (λ (b) (format "      ~a" b)) asm-bindings)
                 (list "    )))"))
         "\n")))

  ;; ── 新增: 操作数类型 ──
  (define types-var (format "~a-operand-types" type-sym))
  (define types-bindings
    (for/list ([idef (in-list defs)])
      (format "(~a . (~a))" (instruction-def-name idef)
              (string-join
               (map (λ (op) (symbol->string (classify-operand op)))
                    (instruction-def-operands idef))
               " "))))
  (define types-def
    (if (null? types-bindings)
        (format "(define ~a (make-immutable-hash '()))" types-var)
        (string-join
         (append (list (format "(define ~a" types-var)
                       "  (make-immutable-hash"
                       "    '(")
                 (map (λ (b) (format "      ~a" b)) types-bindings)
                 (list "    )))"))
         "\n")))

  ;; ── 新增: 宽度常量 ──
  (define width-var (format "~a-width" type-sym))
  (define width-def (format "(define ~a ~a)" width-var width))

  ;; ── 新增: 辅助查询函数 ──
  (define helpers
    (list
     (format "(define (~a-get-param-count mnemonic)" type-sym)
     (format "  (hash-ref ~a mnemonic #f))" param-count-var)
     ""
     (format "(define (~a-get-operands mnemonic)" type-sym)
     (format "  (hash-ref ~a mnemonic '()))" operands-var)
     ""
     (format "(define (~a-get-asm mnemonic)" type-sym)
     (format "  (hash-ref ~a mnemonic #f))" asm-var)
     ""
     (format "(define (~a-get-operand-types mnemonic)" type-sym)
     (format "  (hash-ref ~a mnemonic '()))" types-var)
     ""
     (format "(define (~a-get-width) ~a)" type-sym width-var)
     ""
     (format "(define (~a-exists? mnemonic)" type-sym)
     (format "  (hash-has-key? ~a mnemonic))" param-count-var)
     ""
     (format "(define (~a-get-field-position mnemonic field)" type-sym)
     (format "  (case field")
     (string-join
      (for/list ([f (in-list all-fields)])
        (format "    [(~a) (hash-ref ~a-~a mnemonic #f)]" f type-sym f))
      "\n")
     (format "    [else #f]))")))

  ;; ── provide ──
  (define provide-section
    (string-join
     (append (list "(provide")
            (for/list ([f (in-list all-fields)])
              (format "  ~a-~a" type-sym f))
            (list (format "  ~a" fields-var)
                  (format "  ~a" param-count-var)
                  (format "  ~a" operands-var)
                  (format "  ~a" asm-var)
                  (format "  ~a" types-var)
                  (format "  ~a" width-var)
                  (format "  ~a-get-param-count" type-sym)
                  (format "  ~a-get-operands" type-sym)
                  (format "  ~a-get-asm" type-sym)
                  (format "  ~a-get-operand-types" type-sym)
                  (format "  ~a-get-width" type-sym)
                  (format "  ~a-exists?" type-sym)
                  (format "  ~a-get-field-position)" type-sym)))
     "\n"))

  ;; ── 组装 ──
  (string-join
   (append
    (list "#lang racket" "")
    field-hash-defs
    (list ""
          fields-def
          ""
          param-count-def
          ""
          operands-def
          ""
          asm-def
          ""
          types-def
          ""
          width-def
          ""
          ";; ====== Helper functions ======"
          "")
    helpers
    (list ""
          provide-section
          ""))
   "\n"))

;; ============================================================
;; 全局: 指令 → 扩展映射
;; ============================================================

(define (gen-global-extension-map-content ext-sources)
  (define mapping (make-hash))
  (for ([esrc (in-list ext-sources)])
    (define defs (parse-file (extension-source-path esrc)))
    (for ([idef (in-list defs)])
      (hash-update! mapping
                    (instruction-def-name idef)
                    (λ (lst) (cons (extension-source-type-sym esrc) lst))
                    '())))

  (define sorted-items
    (sort (hash->list mapping) string<? #:key car))

  (string-join
   (append
    (list "#lang racket"
          ""
          "(define instruction->extensions"
          "  (make-immutable-hash"
          "    '(")
    (for/list ([pair (in-list sorted-items)])
      (format "      (~a . (~a))"
              (car pair)
              (string-join (map symbol->string (reverse (cdr pair))) " ")))
    (list "    )))"
          ""
          "(provide instruction->extensions)"
          ""
          ";; ====== Helper functions ======"
          ""
          "(define (get-extensions mnemonic)"
          "  (hash-ref instruction->extensions mnemonic '()))"
          ""
          "(define (get-primary-extension mnemonic)"
          "  (define exts (get-extensions mnemonic))"
          "  (if (null? exts) #f (car exts)))"
          ""
          "(define (instruction-in-extension? mnemonic ext-sym)"
          "  (member ext-sym (get-extensions mnemonic)))"
          ""
          "(provide get-extensions"
          "         get-primary-extension"
          "         instruction-in-extension?)"
          ""))
   "\n"))

;; ============================================================
;; 全局: 指令元数据 (合并所有扩展)
;; ============================================================

(define (gen-global-instruction-meta-content ext-sources)
  ;; 收集所有 meta
  (define all-meta
    (for*/list ([esrc (in-list ext-sources)]
                [idef (in-list (parse-file (extension-source-path esrc)))])
      (list (instruction-def-name idef)
            (extension-source-type-sym esrc)
            (length (instruction-def-operands idef))
            (instruction-def-operands idef)
            (asm-format (instruction-def-name idef)
                        (instruction-def-operands idef))
            (map classify-operand (instruction-def-operands idef))
            (extension-width (extension-source-type-sym esrc)))))

  ;; 排序并去重 (同一指令可能出现在多个扩展中，取第一个)
  (define seen (make-hash))
  (define deduped
    (for/list ([m (in-list all-meta)]
               #:unless (hash-has-key? seen (car m)))
      (hash-set! seen (car m) #t)
      m))

  (define sorted-meta
    (sort deduped string<? #:key car))

  ;; 生成各个哈希
  (define param-count-entries
    (for/list ([m (in-list sorted-meta)])
      (format "      (~a . ~a)" (car m) (caddr m))))

  (define operands-entries
    (for/list ([m (in-list sorted-meta)])
      (format "      (~a . (~a))" (car m)
              (string-join (cadddr m) " "))))

  (define asm-entries
    (for/list ([m (in-list sorted-meta)])
      (format "      (~a . ~s)" (car m) (list-ref m 4))))

  (define types-entries
    (for/list ([m (in-list sorted-meta)])
      (format "      (~a . (~a))" (car m)
              (string-join (map symbol->string (list-ref m 5)) " "))))

  (define width-entries
    (for/list ([m (in-list sorted-meta)])
      (format "      (~a . ~a)" (car m) (list-ref m 6))))

  (string-join
   (list "#lang racket"
         ""
         "(define instruction-param-count"
         "  (make-immutable-hash"
         "    '("
         (string-join param-count-entries "\n")
         "    )))"
         ""
         "(define instruction-operands"
         "  (make-immutable-hash"
         "    '("
         (string-join operands-entries "\n")
         "    )))"
         ""
         "(define instruction-asm"
         "  (make-immutable-hash"
         "    '("
         (string-join asm-entries "\n")
         "    )))"
         ""
         "(define instruction-operand-types"
         "  (make-immutable-hash"
         "    '("
         (string-join types-entries "\n")
         "    )))"
         ""
         "(define instruction-width"
         "  (make-immutable-hash"
         "    '("
         (string-join width-entries "\n")
         "    )))"
         ""
         "(provide instruction-param-count"
         "         instruction-operands"
         "         instruction-asm"
         "         instruction-operand-types"
         "         instruction-width)"
         ""
         ";; ====== Helper functions ======"
         ""
         "(define (get-param-count mnemonic)"
         "  (hash-ref instruction-param-count mnemonic #f))"
         ""
         "(define (get-operands mnemonic)"
         "  (hash-ref instruction-operands mnemonic '()))"
         ""
         "(define (get-asm-format mnemonic)"
         "  (hash-ref instruction-asm mnemonic #f))"
         ""
         "(define (get-operand-types mnemonic)"
         "  (hash-ref instruction-operand-types mnemonic '()))"
         ""
         "(define (get-instruction-width mnemonic)"
         "  (hash-ref instruction-width mnemonic #f))"
         ""
         "(provide get-param-count"
         "         get-operands"
         "         get-asm-format"
         "         get-operand-types"
         "         get-instruction-width)"
         "")
   "\n"))

;; ============================================================
;; 统计文件
;; ============================================================

(define (gen-instruction-counts-content ext-sources)
  (define per-extension '())
  (define all-mnemonics (mutable-set))

  (for ([esrc (in-list ext-sources)])
    (define defs (parse-file (extension-source-path esrc)))
    (define cnt (length defs))
    (set! per-extension
          (cons (cons (extension-source-type-sym esrc) cnt) per-extension))
    (for ([idef (in-list defs)])
      (set-add! all-mnemonics (instruction-def-name idef))))

  (set! per-extension (reverse per-extension))
  (define total-unique (set-count all-mnemonics))
  (define total-with-dup (apply + (map cdr per-extension)))

  (string-join
   (append
    (list "#lang racket"
          ""
          (format "(define total-unique-instructions ~a)" total-unique)
          (format "(define total-instructions-with-duplicates ~a)" total-with-dup)
          ""
          "(define per-extension-instruction-count"
          "  (make-immutable-hash"
          "    '(")
    (for/list ([pair (in-list per-extension)])
      (format "      (~a . ~a)" (car pair) (cdr pair)))
    (list "    )))"
          ""
          "(provide total-unique-instructions"
          "         total-instructions-with-duplicates"
          "         per-extension-instruction-count)"
          ""
          ";; ====== Helper functions ======"
          ""
          "(define (get-extension-instruction-count ext-sym)"
          "  (hash-ref per-extension-instruction-count ext-sym #f))"
          ""
          "(define (list-all-extensions)"
          "  (sort (hash-keys per-extension-instruction-count) symbol<?))"
          ""
          "(define (valid-extension? ext-sym)"
          "  (hash-has-key? per-extension-instruction-count ext-sym))"
          ""
          "(provide get-extension-instruction-count"
          "         list-all-extensions"
          "         valid-extension?)"
          ""))
   "\n"))

;; ============================================================
;; provide
;; ============================================================

(provide
 gen-instruction-code
 gen-instruction-file-content
 gen-instruction-info-file-content
 gen-global-extension-map-content
 gen-global-instruction-meta-content
 gen-instruction-counts-content
 classify-operand
 extension-width
 asm-format)
