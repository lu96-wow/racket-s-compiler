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
;; 寄存器名 → 编号
;; ============================================================
(define reg-table
  (let ([h (make-hash)])
    (for ([pair (in-list
                  '((zero . 0)  (ra . 1)  (sp . 2)  (gp . 3)  (tp . 4)
                    (t0 . 5)    (t1 . 6)  (t2 . 7)
                    (s0 . 8)    (fp . 8)  (s1 . 9)
                    (a0 . 10)   (a1 . 11) (a2 . 12) (a3 . 13)
                    (a4 . 14)   (a5 . 15) (a6 . 16) (a7 . 17)
                    (s2 . 18)   (s3 . 19) (s4 . 20) (s5 . 21)
                    (s6 . 22)   (s7 . 23) (s8 . 24) (s9 . 25)
                    (s10 . 26)  (s11 . 27)
                    (t3 . 28)   (t4 . 29) (t5 . 30) (t6 . 31)))])
      (hash-set! h (car pair) (cdr pair)))
    (for ([i (in-range 32)])
      (hash-set! h (string->symbol (format "x~a" i)) i))
    h))

;; ============================================================
;; 汇编参数顺序 → 编码参数顺序 的重排规则
;; ============================================================
;; 指令函数定义使用编码顺序，而 S 表达式源使用汇编顺序。
;; 对 B-type (beq 等): 汇编 (rs1 rs2 offset) → 编码 (offset rs1 rs2)
;; 对 S-type (sb 等):   汇编 (rs2 rs1 offset) → 编码 (offset rs1 rs2)
(define (make-reorder operands)
  (match operands
    [(list (or 'bimm12) 'rs1 'rs2)  '(2 0 1)]  ;; 汇编(rs1 rs2 off) → 编码(off rs1 rs2)
    [(list (or 'simm12) 'rs1 'rs2)  '(2 1 0)]  ;; 汇编(rs2 rs1 off) → 编码(off rs1 rs2)
    [_  #f]))

(define (reorder-args args reorder)
  (if reorder
      (for/list ([i (in-list reorder)]) (list-ref args i))
      args))

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
        ;; 需要临时寄存器：选一个不与 rd 冲突的
        (define temp (if (= rd-num 5) 6 5))  ;; t0=5, t1=6
        (define insns (load-immediate-number-64 rd-num imm temp))
        (unless insns (error 'li "cannot load immediate ~a in rv64" imm))
        (values insns (* 4 (length insns)))])]
    [else (error 'li "unknown word-size: ~a" word-size)]))

;; ============================================================
;; Pass 1: 布局 —— 算偏移 + 建符号表
;; ============================================================
(define (pass-1 items word-size allowed-exts)
  (define symtab (make-hash))
  (define layout '())
  (define offset 0)

  (for ([item (in-list items)])
    (match item
      [(asm-label name)
       (hash-set! symtab name offset)]
      [(asm-insn 'li (list rd imm))
       (define rd-num (hash-ref reg-table rd))
       (define-values (_ size) (expand-li rd-num imm word-size))
       (set! layout (cons (cons offset item) layout))
       (set! offset (+ offset size))]
      [(asm-insn mnemonic _args)
       (define width (get-instruction-width mnemonic))
       (set! layout (cons (cons offset item) layout))
       (set! offset (+ offset (/ width 8)))]))

  (values (reverse layout) symtab offset))

;; ============================================================
;; Pass 2: 编码 —— 解析符号 + 写出字节
;; ============================================================
(define (pass-2 layout symtab word-size allowed-exts)
  (define out (open-output-bytes))
  (define offset 0)

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
            (define word (apply func resolved))
            (write-bytes (integer->integer-bytes word 4 #f #f) out)
            (set! offset (+ offset 4))]))]

      ;; ── 普通指令 ──
      [(asm-insn mnemonic args)
       (define resolved (map (λ (a) (resolve-arg a symtab offset)) args))
       (define reorder (make-reorder (get-operands mnemonic)))
       (define encoded (reorder-args resolved reorder))
       (define func (get-insn-func mnemonic allowed-exts))
       (define word (apply func encoded))
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
    (pass-1 items word-size exts))
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
