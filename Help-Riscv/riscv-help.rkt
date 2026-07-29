#lang racket

(require "number.rkt")

;; ============================================================
;; 内部辅助
;; ============================================================

;; 32位无符号 → 有符号值
(define (sign-extend-32 v)
  (if (>= v #x80000000) (- v #x100000000) v))

;; 判断 n 是否为某32位值的符号扩展（RV64 Case 2 用）
(define (fits-in-32-bit? n)
  (= n (sign-extend-32 (bitwise-and n #xFFFFFFFF))))

;; 核心：将原始无符号值拆成 (values hi lo)
;;   lo = low12-signed(raw)
;;   hi = raw - lo
;; hi 可能超过当前位宽（如 32位-1时 hi=#x100000000），
;; 调用者（lui/auipc 的 imm20 宏）在编码时自动截断高位。
(define (split-hi-lo raw)
  (define lo (low12-signed raw))
  (values (- raw lo) lo))

;; lo 为 0 时跳过 addi，避免冗余指令
(define (maybe-addi rd reg lo)
  (if (zero? lo) '() `((addi ,rd ,reg ,lo))))

;; RV64 完整64位常量序列（lui/auipc + addi + slli + lui + addi + or）
;; first-op: 'lui 用于加载立即数，'auipc 用于长跳转
(define (build-u64-pair first-op rd use-reg upper-val lower-val)
  (define-values (u-hi u-lo) (split-hi-lo upper-val))
  (define-values (l-hi l-lo) (split-hi-lo lower-val))
  `((,first-op ,rd ,u-hi)
    ,@(maybe-addi rd rd u-lo)
    (slli ,rd ,rd 32)
    (lui ,use-reg ,l-hi)
    ,@(maybe-addi use-reg use-reg l-lo)
    (or ,rd ,rd ,use-reg)))

;; JAL 指令的偏移范围：21位有符号 (±1MB)
(define (jal-offset? offset)
  (<= -1048576 offset 1048575))

;; ============================================================
;; 加载立即数
;; ============================================================

(define (load-immediate-number-32 rd imm)
  (cond
    [(not (exact-integer? imm)) #f]
    [(< imm 0)
     (if (> (min-signed-bits imm) 32) #f (gen-32-load rd imm))]
    [else
     (if (> (min-unsigned-bits imm) 32) #f (gen-32-load rd imm))]))

(define (load-immediate-number-64 rd imm use-reg)
  (cond
    [(not (exact-integer? imm)) #f]
    [(< imm 0)
     (if (> (min-signed-bits imm) 64) #f (gen-64-load rd imm use-reg))]
    [else
     (if (> (min-unsigned-bits imm) 64) #f (gen-64-load rd imm use-reg))]))

;; ── RV32 立即数构造 ──

(define (gen-32-load rd imm)
  (define raw    (bitwise-and imm #xFFFFFFFF))
  (define signed (sign-extend-32 raw))
  (cond
    [(<= -2048 signed 2047)
     `((addi ,rd x0 ,signed))]
    [(low12-zero? raw)
     `((lui ,rd ,raw))]
    [else
     (define-values (hi lo) (split-hi-lo raw))
     `((lui ,rd ,hi)
       (addi ,rd ,rd ,lo))]))

;; ── RV64 立即数构造 ──

(define (gen-64-load rd imm use-reg)
  (cond
    ;; Case 1: 12位有符号 — 单条 addi
    [(<= -2048 imm 2047)
     `((addi ,rd x0 ,imm))]
    ;; Case 2: 来自32位符号扩展 — lui + addiw
    [(fits-in-32-bit? imm)
     (define raw (bitwise-and imm #xFFFFFFFF))
     (define-values (hi lo) (split-hi-lo raw))
     `((lui ,rd ,hi)
       (addiw ,rd ,rd ,lo))]
    ;; Case 3: 低32位全0 — lui(+addi) + slli
    [(= (bitwise-and imm #xFFFFFFFF) 0)
     (define upper (arithmetic-shift imm -32))
     (define-values (hi lo) (split-hi-lo upper))
     (append
      `((lui ,rd ,hi))
      (maybe-addi rd rd lo)
      `((slli ,rd ,rd 32)))]
    ;; Case 4: 完整64位 — 高/低32位分构建后OR
    [else
     (define hi32 (arithmetic-shift imm -32))
     (define lo32 (bitwise-and imm #xFFFFFFFF))
     (build-u64-pair 'lui rd use-reg hi32 lo32)]))

(define (needs-temp-register-for-64? imm)
  (cond
    [(not (exact-integer? imm)) #t]
    [(<= -2048 imm 2047)          #f]
    [(fits-in-32-bit? imm)        #f]
    [(= (bitwise-and imm #xFFFFFFFF) 0) #f]
    [else                         #t]))

;; ============================================================
;; 相对跳转
;; ============================================================

(define (generate-32-jump rd offset)
  (cond
    [(jal-offset? offset)
     `((jal ,rd ,offset))]
    [else
     (define raw (bitwise-and offset #xFFFFFFFF))
     (define-values (hi lo) (split-hi-lo raw))
     `((auipc ,rd ,hi)
       (jalr ,rd ,rd ,lo))]))

(define (generate-64-jump rd offset use-reg)
  (cond
    [(jal-offset? offset)
     `((jal ,rd ,offset))]
    [(<= (- (expt 2 31)) offset (sub1 (expt 2 31)))
     (generate-32-jump rd offset)]
    [else
     (define hi32 (arithmetic-shift offset -32))
     (define lo32 (bitwise-and offset #xFFFFFFFF))
     (append
      (build-u64-pair 'auipc rd use-reg hi32 lo32)
      `((jalr ,rd ,rd 0)))]))

;; ============================================================
;; 绝对地址跳转
;; ============================================================

(define (jump-to-absolute-32 rd addr-reg addr)
  (define insns (load-immediate-number-32 addr-reg addr))
  (and insns (append insns `((jalr ,rd ,addr-reg 0)))))

(define (jump-to-absolute-64 rd addr-reg temp-reg addr)
  (define insns (load-immediate-number-64 addr-reg addr temp-reg))
  (and insns (append insns `((jalr ,rd ,addr-reg 0)))))

;; ============================================================
(provide
 load-immediate-number-32
 load-immediate-number-64
 generate-32-jump
 generate-64-jump
 needs-temp-register-for-64?
 jump-to-absolute-32
 jump-to-absolute-64)
