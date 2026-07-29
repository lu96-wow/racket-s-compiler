#lang racket

(require "../Binary_Build/riscv/instruction_info/instruction_info.rkt"
         "../Binary_Build/riscv/instruction_info/instruction_meta.rkt"
         "../Help-Riscv/riscv-help.rkt"
         racket/match
         racket/runtime-path)

;; ============================================================
;; AST
;; ============================================================
(struct asm-prog (word-size extensions body) #:transparent)
(struct asm-label (name)              #:transparent)
(struct asm-insn (mnemonic args)      #:transparent)

;; ============================================================
;; 解析 S 表达式 → AST
;; ============================================================
(define (parse sexp)
  (match sexp
    [`(asm ,word-size ,exts ,body ...)
     (unless (memq word-size '(rv32 rv64))
       (error 'asm "word-size must be rv32 or rv64, got: ~a" word-size))
     (unless (and (list? exts) (andmap symbol? exts))
       (error 'asm "extensions must be (ext...), got: ~a" exts))
     (asm-prog word-size exts (map parse-item body))]
    [_ (error 'asm "expected (asm rv32|rv64 (ext...) ...)")]))

(define (parse-item item)
  (match item
    [`(label ,(? symbol? name))
     (asm-label name)]
    [`(li ,(? symbol? rd) ,(? exact-integer? imm))
     (asm-insn 'li (list rd imm))]
    [`(,(? symbol? mnemonic) ,args ...)
     (asm-insn mnemonic args)]
    [_ (error 'asm "unexpected item: ~a" item)]))

;; ============================================================
;; 指令函数缓存 (懒加载)
;; ============================================================
(define-runtime-path insn-dir "../Binary_Build/riscv/instruction")
(define insn-func-cache (make-hash))

(define (get-insn-func mnemonic allowed-exts)
  (hash-ref! insn-func-cache mnemonic
    (λ ()
      (define exts (get-extensions mnemonic))
      (define ext (for/or ([e (in-list exts)]
                           #:when (memq e allowed-exts))
                    e))
      (unless ext
        (error 'asm "instruction ~a not in declared extensions ~a"
               mnemonic allowed-exts))
      (define mod-path (build-path insn-dir (format "~a.rkt" ext)))
      (dynamic-require mod-path mnemonic))))

;; ============================================================
;; 寄存器名 → 编号（加载 register.rkt 一次，枚举全部导出）
;; ============================================================
(define-runtime-path reg-path "../Binary_Build/riscv/register.rkt")
(define reg-table
  (let ([ns (make-base-empty-namespace)])
    (parameterize ([current-namespace ns])
      (namespace-require `(file ,(path->string reg-path))))
    (for/hash ([sym (in-list (namespace-mapped-symbols ns))])
      (define val (namespace-variable-value sym #t #f ns))
      (when (exact-integer? val)
        (values sym val)))))

(define (branch-mnemonic? mnemonic)
  (memq mnemonic '(beq bne blt bge bltu bgeu)))

;; ============================================================
;; 符号解析：arg → 具体整数值
;; ============================================================
(define (resolve-arg arg symtab current-offset)
  (cond
    [(exact-integer? arg)  arg]
    [(hash-ref reg-table arg #f)]
    [(hash-ref symtab arg #f)
     => (λ (target) (- target current-offset))]
    [else (error 'asm "unresolved symbol: ~a" arg)]))

;; ============================================================
;; li 展开（统一入口，返回指令形式列表 + 总字节数）
;; ============================================================
(define (expand-li rd-num imm word-size)
  (cond
    [(eq? word-size 'rv32)
     (define insns (load-immediate-number-32 rd-num imm))
     (unless insns (error 'li "cannot load immediate ~a in rv32" imm))
     (values insns (* 4 (length insns)))]
    [(eq? word-size 'rv64)
     (cond
       [(not (needs-temp-register-for-64? imm))
        (define insns (load-immediate-number-64 rd-num imm rd-num))
        (unless insns (error 'li "cannot load immediate ~a in rv64" imm))
        (values insns (* 4 (length insns)))]
       [else
        (define temp (if (= rd-num 5) 6 5))  ;; t0=5, t1=6
        (define insns (load-immediate-number-64 rd-num imm temp))
        (unless insns (error 'li "cannot load immediate ~a in rv64" imm))
        (values insns (* 4 (length insns)))])]
    [else (error 'li "unknown word-size: ~a" word-size)]))

;; ============================================================
;; 分支展开（封装 expand-branch-if-needed 的调用细节）
;; 返回 (values expanded-list byte-size)
;; 若 offset 已知且在范围内则返回 (values #f 4)
;; ============================================================
(define (branch-size mnemonic off-sym rs1-sym rs2-sym symtab current-offset word-size)
  (match (hash-ref symtab off-sym #f)
    [#f 4]  ;; 向前跳转，未知偏移，保守假设 4 字节
    [target
     (define branch-off (- target current-offset))
     (define rs1-num (hash-ref reg-table rs1-sym))
     (define rs2-num (hash-ref reg-table rs2-sym))
     (let-values ([(expanded esize)
                   (expand-branch-if-needed mnemonic branch-off rs1-num rs2-num word-size)])
       (if expanded esize 4))]))

;; ============================================================
;; Pass 1: 布局 —— 算偏移 + 建符号表
;; forced-sizes: item-index → 强制使用的字节数（松弛用），缺省则自动计算
;; ============================================================
(define (pass-1 items word-size allowed-exts [forced-sizes (hash)])
  (define symtab (make-hash))
  (define layout '())
  (define offset 0)

  (for ([item (in-list items)]
        [idx (in-naturals)])
    (match item
      [(asm-label name)
       (hash-set! symtab name offset)]
      [(asm-insn 'li (list rd imm))
       (define rd-num (hash-ref reg-table rd))
       (define-values (_ size) (expand-li rd-num imm word-size))
       (set! layout (cons (cons offset item) layout))
       (set! offset (+ offset size))]
      [(asm-insn mnemonic (list off-sym rs1-sym rs2-sym))
       #:when (branch-mnemonic? mnemonic)
       (define size (or (hash-ref forced-sizes idx #f)
                        (branch-size mnemonic off-sym rs1-sym rs2-sym symtab offset word-size)))
       (set! layout (cons (cons offset item) layout))
       (set! offset (+ offset size))]
      [(asm-insn mnemonic _args)
       (define width (get-instruction-width mnemonic))
       (set! layout (cons (cons offset item) layout))
       (set! offset (+ offset (/ width 8)))]))

  (values (reverse layout) symtab offset))

;; ============================================================
;; 松弛迭代：反复 Pass 1 直到所有分支偏移收敛
;; ============================================================
(define (relax items word-size allowed-exts)
  (define forced-sizes (make-hash))  ;; item-index → byte-size

  (let loop ([iter 0])
    (define-values (layout symtab total)
      (pass-1 items word-size allowed-exts forced-sizes))

    (define any-change? #f)
    (for ([item (in-list items)]
          [idx (in-naturals)])
      (match (cons item (list-ref-null layout idx))
        ;; layout 里对应位置的 (offset . item)
        [(list (asm-insn mnemonic (list off-sym rs1-sym rs2-sym))
               offset
               _)
         #:when (branch-mnemonic? mnemonic)
         (define target (hash-ref symtab off-sym #f))
         (when target
           (define b-off (- target offset))
           (unless (fits-branch-offset? b-off)
             (define rs1-num (hash-ref reg-table rs1-sym))
             (define rs2-num (hash-ref reg-table rs2-sym))
             (let-values ([(expanded esize)
                           (expand-branch-if-needed mnemonic b-off rs1-num rs2-num word-size)])
               (unless (= (hash-ref forced-sizes idx 4) esize)
                 (hash-set! forced-sizes idx esize)
                 (set! any-change? #t)))))]
        [_ (void)]))

    (if (and any-change? (< iter 10))
        (loop (add1 iter))
        (values layout symtab total))))

;; 辅助：从 layout 取第 idx 个元素（layout 是 (cons offset item) 的列表）
(define (list-ref-null lst idx)
  (cond [(null? lst) #f]
        [(zero? idx) (car lst)]
        [else (list-ref-null (cdr lst) (sub1 idx))]))

;; ============================================================
;; Pass 2: 编码 —— 解析符号 + 写出字节
;; ============================================================
(define (pass-2 layout symtab word-size allowed-exts)
  (define out (open-output-bytes))
  (define offset 0)

  (define (emit-word func args)
    (define word (apply func args))
    (write-bytes (integer->integer-bytes word 4 #f #f) out)
    (set! offset (+ offset 4)))

  (for ([pair (in-list layout)])
    (match-define (cons _orig-offset item) pair)

    (match item
      ;; ── li 伪指令 → 展开后逐条编码 ──
      [(asm-insn 'li (list rd imm))
       (define rd-num (hash-ref reg-table rd))
       (define-values (expanded _) (expand-li rd-num imm word-size))
       (for ([form (in-list expanded)])
         (match form
           [`(,mn ,args ...)
            (define resolved (map (λ (a) (resolve-arg a symtab offset)) args))
            (define func (get-insn-func mn allowed-exts))
            (emit-word func resolved)]))]

      ;; ── 分支指令（可能需要展开）──
      [(asm-insn (and mnemonic (? branch-mnemonic?)) (list off-sym rs1-sym rs2-sym))
       (define resolved-rs1 (resolve-arg rs1-sym symtab offset))
       (define resolved-rs2 (resolve-arg rs2-sym symtab offset))
       (define branch-off (resolve-arg off-sym symtab offset))
       (let-values ([(expanded _)
                     (expand-branch-if-needed
                      mnemonic branch-off resolved-rs1 resolved-rs2 word-size)])
         (if expanded
             (for ([form (in-list expanded)])
               (match form
                 [`(,mn ,as ...)
                  (define rs (map (λ (a) (resolve-arg a symtab offset)) as))
                  (define func (get-insn-func mn allowed-exts))
                  (emit-word func rs)]))
             (let ([func (get-insn-func mnemonic allowed-exts)])
               (emit-word func (list branch-off resolved-rs1 resolved-rs2)))))]

      ;; ── 普通指令 ──
      [(asm-insn mnemonic args)
       (define resolved (map (λ (a) (resolve-arg a symtab offset)) args))
       (define func (get-insn-func mnemonic allowed-exts))
       (define word (apply func resolved))
       (define width (get-instruction-width mnemonic))
       (write-bytes (integer->integer-bytes word (/ width 8) #f #f) out)
       (set! offset (+ offset (/ width 8)))]))

  (get-output-bytes out))

;; ============================================================
;; 主入口
;; ============================================================
(define (assemble-sexp sexp)
  (define prog (parse sexp))
  (match-define (asm-prog word-size exts items) prog)
  (define-values (layout symtab _total)
    (relax items word-size exts))
  (pass-2 layout symtab word-size exts))

(define (assemble-file path)
  (call-with-input-file path
    (λ (in)
      (let loop ()
        (define s (read in))
        (if (eof-object? s)
            #""
            (assemble-sexp s))))))

(provide
 assemble-sexp
 assemble-file
 ;; 也暴露 AST 供调试
 asm-prog? asm-prog-word-size asm-prog-extensions asm-prog-body
 asm-label? asm-label-name
 asm-insn? asm-insn-mnemonic asm-insn-args
 (contract-out [parse (-> any/c asm-prog?)]))
