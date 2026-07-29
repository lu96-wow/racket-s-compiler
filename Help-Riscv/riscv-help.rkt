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

;; 根据 hi/lo 生成最优 lui/addi 指令序列
;;   hi=0       → ((addi rd x0 lo))          (12位有符号，省掉 lui)
;;   lo=0       → ((lui rd hi))              (低12位为0，省掉 addi)
;;   hi≠0, lo≠0 → ((lui rd hi) (addi rd rd lo))
(define (emit-hi-lo rd hi lo)
  (cond
    [(zero? hi)  `((addi ,rd x0 ,lo))]
    [(zero? lo)  `((lui ,rd ,hi))]
    [else        `((lui ,rd ,hi) (addi ,rd ,rd ,lo))]))

;; RV64 完整64位常量序列（slli + or 包装）
(define (build-u64-pair rd use-reg upper-val lower-val)
  (define-values (u-hi u-lo) (split-hi-lo upper-val))
  (define-values (l-hi l-lo) (split-hi-lo lower-val))
  `(,@(emit-hi-lo rd u-hi u-lo)
    (slli ,rd ,rd 32)
    ,@(emit-hi-lo use-reg l-hi l-lo)
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
  ;; 12位有符号范围内直接 addi，避免 hi=0x100000000 导致假的 lui
  (if (<= -2048 signed 2047)
      `((addi ,rd x0 ,signed))
      (let-values ([(hi lo) (split-hi-lo raw)])
        (emit-hi-lo rd hi lo))))

;; ── RV64 立即数构造 ──

(define (gen-64-load rd imm use-reg)
  (cond
    ;; Case 1: 12位有符号 — 单条 addi（必须优先，否则负数进入 Case 2 会生成假的 lui）
    [(<= -2048 imm 2047)
     `((addi ,rd x0 ,imm))]
    ;; Case 2: 来自32位符号扩展 — lui + addi(addiw同效)
    [(fits-in-32-bit? imm)
     (let ([raw (bitwise-and imm #xFFFFFFFF)])
       (let-values ([(hi lo) (split-hi-lo raw)])
         (emit-hi-lo rd hi lo)))]
    ;; Case 3: 低32位全0 — build upper32 + slli 32
    [(= (bitwise-and imm #xFFFFFFFF) 0)
     (let ([upper (arithmetic-shift imm -32)])
       (let-values ([(hi lo) (split-hi-lo upper)])
         (append (emit-hi-lo rd hi lo)
                 `((slli ,rd ,rd 32)))))]
    ;; Case 4: 完整64位 — 高/低32位分构建后OR
    [else
     (let ([hi32 (arithmetic-shift imm -32)]
           [lo32 (bitwise-and imm #xFFFFFFFF)])
       (build-u64-pair rd use-reg hi32 lo32))]))

;; 预测：加载这个 64 位立即数是否需要辅助寄存器（Case 4 才需要）
(define (needs-temp-register-for-64? imm)
  (and (exact-integer? imm)
       (not (<= -2048 imm 2047))
       (not (fits-in-32-bit? imm))
       (not (= (bitwise-and imm #xFFFFFFFF) 0))))

;; ============================================================
;; 相对跳转
;; ============================================================

(define (generate-32-jump rd offset)
  (cond
    [(jal-offset? offset)
     `((jal ,rd ,offset))]
    [else
     (let ([raw (bitwise-and offset #xFFFFFFFF)])
       (let-values ([(hi lo) (split-hi-lo raw)])
         `((auipc ,rd ,hi)
           (jalr ,rd ,rd ,lo))))]))

(define (generate-64-jump rd offset use-reg)
  (cond
    [(jal-offset? offset)
     `((jal ,rd ,offset))]
    [(<= (- (expt 2 31)) offset (sub1 (expt 2 31)))
     (generate-32-jump rd offset)]
    [else
     ;; 超 32 位偏移: 先将完整 offset 加载到 use-reg，
     ;; 再 AUIPC 捕获 PC，相加后 JALR。
     ;; use-reg 装偏移量，rd 同时作为 link 和 AUIPC 目标。
     (let ([load-offset (load-immediate-number-64 use-reg offset rd)])
       (and load-offset
            (append load-offset
                    `((auipc ,rd 0)
                      (add ,rd ,rd ,use-reg)
                      (jalr ,rd ,rd 0)))))]))

;; ============================================================
;; 绝对地址跳转
;; ============================================================

(define (jump-to-absolute-32 rd addr-reg addr)
  (let ([insns (load-immediate-number-32 addr-reg addr)])
    (and insns (append insns `((jalr ,rd ,addr-reg 0))))))

(define (jump-to-absolute-64 rd addr-reg temp-reg addr)
  (let ([insns (load-immediate-number-64 addr-reg addr temp-reg)])
    (and insns (append insns `((jalr ,rd ,addr-reg 0))))))

;; ============================================================
(provide
 load-immediate-number-32
 load-immediate-number-64
 generate-32-jump
 generate-64-jump
 needs-temp-register-for-64?
 jump-to-absolute-32
 jump-to-absolute-64)
