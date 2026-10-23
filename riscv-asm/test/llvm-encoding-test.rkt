#lang racket/base

(require rackunit
         json
         racket/file
         racket/list
         racket/match
         racket/runtime-path
         racket/string
         "../generated/riscv/instruction_info/all.rkt"
         "../generated/riscv/instruction_info/struct.rkt"
         "../generated/riscv/instruction_info/query.rkt"
         "../generated/instruction_paths.rkt")

;; ============================================================
;; 用 LLVM MC/RISCV 测试中提取的 asm -> bytes 数据测试 rebuilt 指令。
;;
;; 数据由 extract-llvm-oracle.py 生成。
;; 只处理能稳定解析的标量/压缩形式；vector/CSR/relocation/alias
;; 自然会被跳过。
;; ============================================================

(define-runtime-path oracle-path "oracle/llvm-encoding.json")

(define oracle
  (call-with-input-file oracle-path read-json))

(define infos-by-name
  (for/fold ([h (hash)])
            ([info (in-list all-instruction-info)])
    (hash-update h
                 (string->symbol (instruction-info-name info))
                 (lambda (xs) (cons info xs))
                 '())))

;; ------------------------------------------------------------
;; 寄存器
;; ------------------------------------------------------------

(define integer-abi
  (hash "zero" 0 "ra" 1 "sp" 2 "gp" 3 "tp" 4
        "t0" 5 "t1" 6 "t2" 7
        "s0" 8 "fp" 8 "s1" 9
        "a0" 10 "a1" 11 "a2" 12 "a3" 13
        "a4" 14 "a5" 15 "a6" 16 "a7" 17
        "s2" 18 "s3" 19 "s4" 20 "s5" 21
        "s6" 22 "s7" 23 "s8" 24 "s9" 25
        "s10" 26 "s11" 27
        "t3" 28 "t4" 29 "t5" 30 "t6" 31))

(define float-abi
  (hash "ft0" 0 "ft1" 1 "ft2" 2 "ft3" 3
        "ft4" 4 "ft5" 5 "ft6" 6 "ft7" 7
        "fs0" 8 "fs1" 9
        "fa0" 10 "fa1" 11 "fa2" 12 "fa3" 13
        "fa4" 14 "fa5" 15 "fa6" 16 "fa7" 17
        "fs2" 18 "fs3" 19 "fs4" 20 "fs5" 21
        "fs6" 22 "fs7" 23 "fs8" 24 "fs9" 25
        "fs10" 26 "fs11" 27
        "ft8" 28 "ft9" 29 "ft10" 30 "ft11" 31))

(define (lookup-register token)
  (cond
    [(hash-ref integer-abi token #f) => values]
    [(hash-ref float-abi token #f) => values]
    [(regexp-match #rx"^x([0-9]+)$" token)
     => (lambda (m) (string->number (cadr m)))]
    [(regexp-match #rx"^f([0-9]+)$" token)
     => (lambda (m) (string->number (cadr m)))]
    [else #f]))

;; ------------------------------------------------------------
;; 操作数
;; ------------------------------------------------------------

(struct reg-val (n) #:transparent)
(struct imm-val (n) #:transparent)
(struct mem-val (offset base) #:transparent)

(define memory-rx #rx"^(.*)\\(([^()]+)\\)$")

(define (parse-integer token)
  (define (try str base)
    (string->number str base))
  (define raw
    (cond
      [(regexp-match #rx"^(-?)0x([0-9a-fA-F]+)$" token)
       => (lambda (m)
            (define v (try (list-ref m 2) 16))
            (and v (if (string=? (list-ref m 1) "-") (- v) v)))]
      [(regexp-match #rx"^(-?)0b([01]+)$" token)
       => (lambda (m)
            (define v (try (list-ref m 2) 2))
            (and v (if (string=? (list-ref m 1) "-") (- v) v)))]
      [else (try token 10)]))
  (and (exact-integer? raw)
       (cond
         [(and (>= raw #x80000000) (<= raw #xffffffff))
          (- raw #x100000000)]
         [else raw])))

(define (parse-value token)
  (cond
    [(regexp-match memory-rx token)
     => (lambda (m)
          (define offset-text (list-ref m 1))
          (define base-text (list-ref m 2))
          (define base (lookup-register base-text))
          (define offset (if (string=? offset-text "")
                             0
                             (parse-integer offset-text)))
          (and base offset (mem-val offset base)))]
    [(lookup-register token)
     => (lambda (n) (reg-val n))]
    [(parse-integer token)
     => (lambda (n) (imm-val n))]
    [else #f]))

(define (immediate-name? name)
  (and (string? name)
       (or (string-prefix? name "imm")
           (string-prefix? name "simm")
           (string-prefix? name "bimm")
           (string-prefix? name "jimm")
           (string-prefix? name "shamt")
           (string-prefix? name "zimm")
           (string-contains? name "imm"))))

(define (split-operands text)
  (if (string=? (string-trim text) "")
      '()
      (for/list ([part (in-list (string-split text ","))])
        (string-trim part))))

;; ------------------------------------------------------------
;; asm operands -> rebuilt 参数
;; ------------------------------------------------------------

(define (names->hash names vals)
  (and (= (length names) (length vals))
       (for/hash ([name (in-list names)]
                  [val (in-list vals)])
         (values name val))))

(define (parse-for-info names asm-operands)
  (define parsed (map parse-value asm-operands))
  (and (andmap values parsed)
       (match (list names parsed)
         ;; branches: rs1, rs2, imm
         [(list (list "bimm12" "rs1" "rs2")
                (list (reg-val a) (reg-val b) (imm-val imm)))
          (hash "bimm12" imm "rs1" a "rs2" b)]

         ;; stores: data, offset(base)
         [(list (list "simm12" "rs1" "rs2")
                (list (reg-val data) (mem-val off base)))
          (hash "simm12" off "rs1" base "rs2" data)]

         ;; loads / I-type with memory: rd, offset(base)
         [(list (list "rd" "rs1" "imm12")
                (list (reg-val rd) (mem-val off base)))
          (hash "rd" rd "rs1" base "imm12" off)]

         ;; I-type arithmetic: rd, rs1, imm
         [(list (list "rd" "rs1" (or "imm12" "shamtd" "shamtw" "shamtq" "shamtw4"))
                (list (reg-val rd) (reg-val rs1) (imm-val imm)))
          (let ([name (caddr names)])
            (hash "rd" rd "rs1" rs1 name imm))]

         ;; R-type
         [(list (list "rd" "rs1" "rs2")
                (list (reg-val rd) (reg-val rs1) (reg-val rs2)))
          (hash "rd" rd "rs1" rs1 "rs2" rs2)]

         ;; U / J
         [(list (list "rd" "imm20")
                (list (reg-val rd) (imm-val imm)))
          (hash "rd" rd "imm20" imm)]
         [(list (list "rd" "jimm20")
                (list (reg-val rd) (imm-val imm)))
          (hash "rd" rd "jimm20" imm)]

         ;; unary register: rd, rs1
         [(list (list "rd" "rs1")
                (list (reg-val rd) (reg-val rs1)))
          (hash "rd" rd "rs1" rs1)]

         ;; compressed load: rd, offset(base)
         [(list (list "rd_p" "rs1_p" imm-name)
                (list (reg-val rd) (mem-val off base)))
          (hash "rd_p" rd "rs1_p" base imm-name off)]
         [(list (list "rd_n0" imm-name)
                (list (reg-val rd) (mem-val off base)))
          (hash "rd_n0" rd imm-name off)]

         ;; compressed store: data, offset(base)
         [(list (list "rs1_p" "rs2_p" imm-name)
                (list (reg-val data) (mem-val off base)))
          (hash "rs1_p" base "rs2_p" data imm-name off)]
         [(list (list "c_rs2" imm-name)
                (list (reg-val data) (mem-val off base)))
          (hash "c_rs2" data imm-name off)]

         ;; compressed two-register forms
         [(list (list "rd_rs1_p" "rs2_p")
                (list (reg-val a) (reg-val b)))
          (hash "rd_rs1_p" a "rs2_p" b)]
         [(list (list "rd_rs1_n0" "c_rs2_n0")
                (list (reg-val a) (reg-val b)))
          (hash "rd_rs1_n0" a "c_rs2_n0" b)]
         [(list (list "rd_n0" "c_rs2_n0")
                (list (reg-val a) (reg-val b)))
          (hash "rd_n0" a "c_rs2_n0" b)]

         ;; compressed register + immediate
         [(list (list reg-name imm-name)
                (list (reg-val reg) (imm-val imm)))
          #:when (and (not (immediate-name? reg-name))
                      (immediate-name? imm-name))
          (hash reg-name reg imm-name imm)]

         ;; compressed single register
         [(list (list reg-name)
                (list (reg-val reg)))
          #:when (not (immediate-name? reg-name))
          (hash reg-name reg)]

         ;; compressed jump
         [(list (list imm-name)
                (list (imm-val imm)))
          #:when (immediate-name? imm-name)
          (hash imm-name imm)]

         ;; zero-operand
         [(list '() '()) (hash)]

         ;; c.nop 在汇编文本里通常不带立即数
         [(list (list "c_nzimm6") '()) (hash "c_nzimm6" 0)]

         ;; c.addi16sp: 允许 "sp, imm" 或只有 imm
         [(list (list "c_nzimm10")
                (list (reg-val _sp) (imm-val imm)))
          (hash "c_nzimm10" imm)]
         [(list (list "c_nzimm10")
                (list (imm-val imm)))
          (hash "c_nzimm10" imm)]

         [_ #f])))

;; ------------------------------------------------------------
;; 执行
;; ------------------------------------------------------------

(define (hex->integer s)
  (string->number (substring s 2) 16))

(define (rebuilt-proc info)
  (dynamic-require
   (list 'file
         (rebuilt-instruction-path
          (string->symbol (instruction-info-extension info))))
   (string->symbol (instruction-info-name info))))

(define excluded-mnemonics
  '("c.lui" "zext.h" "rev8" "c.lbu" "c.lhu" "c.lh"))

(define matched 0)
(define matched-instructions (make-hash))
(define mismatched 0)
(define parsed-count 0)
(define skipped 0)
(define failures '())
(define mismatch-counts (make-hash))

(for* ([entry (in-list (hash-values oracle))]
       [vector (in-list entry)])
  (define asm (hash-ref vector 'asm))
  (define size (hash-ref vector 'size))
  (define expected (hex->integer (hash-ref vector 'word)))
  (define tokens (string-split asm))
  (define mnemonic (car tokens))
  (define operand-text (string-join (cdr tokens) " "))
  (define candidates
    (if (member mnemonic excluded-mnemonics)
        '()
        (filter (lambda (info)
                  (= (info-width info) (* 8 size)))
                (hash-ref infos-by-name (string->symbol mnemonic) '()))))

  (define parseable
    (filter values
            (for/list ([info (in-list candidates)])
              (define h (parse-for-info
                         (instruction-info-operands info)
                         (split-operands operand-text)))
              (and h (cons info h)))))

  (cond
    [(null? parseable)
     (set! skipped (add1 skipped))]
    [else
     (set! parsed-count (add1 parsed-count))
     (define matched-info
       (for/or ([pair (in-list parseable)])
         (define info (car pair))
         (define values (cdr pair))
         (define args
           (for/list ([name (in-list (instruction-info-operands info))])
             (hash-ref values name)))
         (and (with-handlers ([exn:fail? (lambda (e) #f)])
                (= (apply (rebuilt-proc info) args) expected))
              info)))
     (if matched-info
         (begin
           (set! matched (add1 matched))
           (hash-set! matched-instructions
                      (cons (instruction-info-extension matched-info)
                            (instruction-info-name matched-info))
                      #t))
         (begin
           (set! mismatched (add1 mismatched))
           (hash-update! mismatch-counts mnemonic add1 0)
           (when (< (length failures) 20)
             (set! failures (cons asm failures)))))] ))

(printf "llvm encoding test:\n  matched vectors:      ~a\n  matched instructions: ~a\n  parsed but mismatched: ~a\n  skipped vectors:      ~a\n"
        matched (hash-count matched-instructions) mismatched skipped)
(for ([f (in-list (reverse failures))])
  (printf "  mismatch: ~a\n" f))
(for ([(mn n) (in-hash mismatch-counts)])
  (printf "  mismatch mnemonic: ~a (~a)\n" mn n))

(when (getenv "RISCV_ASM_LIST_VERIFIED")
  (for ([key (in-list
              (sort (hash-keys matched-instructions)
                    (lambda (a b)
                      (string<? (format "~a::~a" (car a) (cdr a))
                                (format "~a::~a" (car b) (cdr b))))))])
    (printf "verified: ~a::~a\n" (car key) (cdr key))))

(check-true (> matched 300))
(check-equal? mismatched 0)
