#lang racket

(require "../Binary_Build/riscv/instruction_info/instruction_info.rkt"
         "../Binary_Build/riscv/instruction_info/instruction_meta.rkt"
         "../Help-Riscv/riscv-help.rkt"
         racket/match
         racket/runtime-path)

;; ============================================================
;; AST
;; ============================================================
(struct asm-label (name)         #:transparent)
(struct asm-insn (mnemonic args) #:transparent)
(struct asm-space (size)         #:transparent)

;; ============================================================
;; 环境初始化（由 main.rkt 在解析 asm 声明后调用）
;; ============================================================
(define-runtime-path insn-dir "../Binary_Build/riscv/instruction")
(define-runtime-path reg-path "../Binary_Build/riscv/register.rkt")

(define (init-reg-table)
  (let ([ns (make-base-empty-namespace)])
    (parameterize ([current-namespace ns])
      (namespace-require `(file ,(path->string reg-path))))
    (for/hash ([sym (in-list (namespace-mapped-symbols ns))])
      (define val (namespace-variable-value sym #t #f ns))
      (when (exact-integer? val) (values sym val)))))

(define reg-table (init-reg-table))

(define (reg-num sym)
  (hash-ref reg-table sym #f))

(define insn-cache (make-hash))
(define insn-exts '())

(define (init-insn-funcs allowed-exts)
  (set! insn-exts allowed-exts))

(define (load-insn mnemonic)
  (hash-ref! insn-cache mnemonic
    (λ ()
      (define exts (get-extensions mnemonic))
      (define ext (for/or ([e (in-list exts)] #:when (memq e insn-exts)) e))
      (unless ext (error 'asm "instruction ~a not in declared extensions ~a" mnemonic insn-exts))
      (dynamic-require (build-path insn-dir (format "~a.rkt" ext)) mnemonic))))

;; ============================================================
;; 解析（main.rkt 已经把 S 表达式转成了 items）
;; ============================================================

(define (branch-mnemonic? m) (memq m '(beq bne blt bge bltu bgeu)))

;; ============================================================
;; 符号解析
;; ============================================================
(define (resolve-arg arg symtab current-offset)
  (cond
    [(exact-integer? arg)  arg]
    [(reg-num arg)]
    [(hash-ref symtab arg #f) => (λ (t) (- t current-offset))]
    [else (error 'asm "unresolved symbol: ~a" arg)]))

;; ============================================================
;; li 展开
;; ============================================================
(define (li-expand rd-num imm word-size)
  (define insns
    (cond [(eq? word-size 'rv32) (load-immediate-number-32 rd-num imm)]
          [(eq? word-size 'rv64)
           (if (needs-temp-register-for-64? imm)
               (let ([temp (if (= rd-num 5) 6 5)])
                 (load-immediate-number-64 rd-num imm temp))
               (load-immediate-number-64 rd-num imm rd-num))]
          [else (error 'li "unknown word-size: ~a" word-size)]))
  (unless insns (error 'li "cannot load immediate ~a in ~a" imm word-size))
  (values insns (* 4 (length insns))))

;; ============================================================
;; 分支尺寸
;; ============================================================
(define (branch-size mnemonic off-sym rs1 rs2 symtab current-offset word-size)
  (match (hash-ref symtab off-sym #f)
    [#f 4]
    [target
     (define b-off (- target current-offset))
     (let-values ([(expanded esize)
                   (expand-branch-if-needed mnemonic b-off (reg-num rs1) (reg-num rs2) word-size)])
       (if expanded esize 4))]))

;; ============================================================
;; Pass 1
;; ============================================================
(define (pass-1 items word-size forced-sizes)
  (define symtab (make-hash))
  (define layout '())
  (define offset 0)

  (for ([item (in-list items)] [idx (in-naturals)])
    (match item
      [(asm-label name)
       (hash-set! symtab name offset)
       (set! layout (cons (cons offset item) layout))]
      [(asm-space size)
       (set! layout (cons (cons offset item) layout))
       (set! offset (+ offset size))]
      [(asm-insn 'li (list rd imm))
       (define rd-num (reg-num rd))
       (let-values ([(insns size) (li-expand rd-num imm word-size)])
         (set! layout (cons (cons offset item) layout))
         (set! offset (+ offset size)))]
      [(asm-insn mnemonic (list off-sym rs1 rs2))
       #:when (branch-mnemonic? mnemonic)
       (define size (or (hash-ref forced-sizes idx #f)
                        (branch-size mnemonic off-sym rs1 rs2 symtab offset word-size)))
       (set! layout (cons (cons offset item) layout))
       (set! offset (+ offset size))]
      [(asm-insn mnemonic _args)
       (define w (get-instruction-width mnemonic))
       (set! layout (cons (cons offset item) layout))
       (set! offset (+ offset (/ w 8)))]))

  (values (reverse layout) symtab offset))

;; ============================================================
;; 松弛
;; ============================================================
(define (relax items word-size)
  (define-values (init-layout symtab _) (pass-1 items word-size (hash)))
  (define n (length init-layout))

  (define sizes (make-vector n))
  (for ([i (in-range n)])
    (match-define (cons off _) (list-ref init-layout i))
    (define next (if (< i (sub1 n)) (car (list-ref init-layout (add1 i))) (+ off 4)))
    (vector-set! sizes i (- next off)))

  (define label-idx (make-hash))
  (for ([i (in-range n)])
    (match (list-ref init-layout i)
      [(cons _ (asm-label name)) (hash-set! label-idx name i)]
      [_ (void)]))

  (define (label-addr name)
    (define idx (hash-ref label-idx name #f))
    (and idx (for/sum ([j (in-range idx)]) (vector-ref sizes j))))
  (define (item-addr i) (for/sum ([j (in-range i)]) (vector-ref sizes j)))

  (let loop ()
    (define changed? #f)
    (for ([i (in-range (sub1 n) -1 -1)])
      (match (list-ref init-layout i)
        [(cons _ (asm-insn (and mnemonic (? branch-mnemonic?)) (list off-sym rs1 rs2)))
         (define target (label-addr off-sym))
         (when target
           (define b-off (- target (item-addr i)))
           (let-values ([(expanded esize)
                         (expand-branch-if-needed mnemonic b-off (reg-num rs1) (reg-num rs2) word-size)])
             (when (and expanded (not (= esize (vector-ref sizes i))))
               (vector-set! sizes i esize)
               (set! changed? #t))))]
        [_ (void)]))
    (when changed? (loop)))

  (define forced (make-hash))
  (for ([i (in-range n)])
    (match-define (cons off _) (list-ref init-layout i))
    (define orig (let ([next (if (< i (sub1 n)) (car (list-ref init-layout (add1 i))) (+ off 4))])
                   (- next off)))
    (unless (= orig (vector-ref sizes i))
      (hash-set! forced i (vector-ref sizes i))))

  (pass-1 items word-size forced))

;; ============================================================
;; Pass 2
;; ============================================================
(define (pass-2 layout symtab word-size)
  (define out (open-output-bytes))
  (define offset 0)

  (define (emit-word func args)
    (define word (apply func args))
    (write-bytes (integer->integer-bytes word 4 #f #f) out)
    (set! offset (+ offset 4)))

  (define (encode form)
    (match form
      [`(,mn ,args ...)
       (define func (load-insn mn))
       (emit-word func (map (λ (a) (resolve-arg a symtab offset)) args))]))

  (for ([pair (in-list layout)])
    (match-define (cons _ item) pair)
    (match item
      [(asm-label _) (void)]
      [(asm-space size)
       (write-bytes (make-bytes size 0) out)
       (set! offset (+ offset size))]
      [(asm-insn 'li (list rd imm))
       (let-values ([(expanded _) (li-expand (reg-num rd) imm word-size)])
         (for ([f (in-list expanded)]) (encode f)))]
      [(asm-insn (and mnemonic (? branch-mnemonic?)) (list off-sym rs1 rs2))
       (define off (resolve-arg off-sym symtab offset))
       (define r1 (reg-num rs1))
       (define r2 (reg-num rs2))
       (let-values ([(expanded _) (expand-branch-if-needed mnemonic off r1 r2 word-size)])
         (if expanded
             (for ([f (in-list expanded)]) (encode f))
             (let ([func (load-insn mnemonic)])
               (emit-word func (list off r1 r2)))))]
      [(asm-insn mnemonic args)
       (define resolved (map (λ (a) (resolve-arg a symtab offset)) args))
       (define func (load-insn mnemonic))
       (define word (apply func resolved))
       (define w (get-instruction-width mnemonic))
       (write-bytes (integer->integer-bytes word (/ w 8) #f #f) out)
       (set! offset (+ offset (/ w 8)))]))

  (get-output-bytes out))

;; ============================================================
;; 入口
;; ============================================================
(define (assemble items word-size allowed-exts)
  (init-insn-funcs allowed-exts)
  (define-values (layout symtab _) (relax items word-size))
  (pass-2 layout symtab word-size))

(provide assemble reg-num asm-label asm-insn asm-space asm-label? asm-insn? asm-space?)
