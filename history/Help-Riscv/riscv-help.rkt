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
  ;; 64位值是否来自32位值的符号扩展
  ;; 用64位掩码统一处理正/负数（Racket 整数无限精度，负数需要截断到64位）
  (let ([n64 (bitwise-and n #xFFFFFFFFFFFFFFFF)])
    (= n64 (bitwise-and (sign-extend-32 (bitwise-and n64 #xFFFFFFFF))
                        #xFFFFFFFFFFFFFFFF))))

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
;; build-u64-pair: 高/低 32 位切片组合
;;   upper 切片只需低 32 位正确 (slli 后低位移出) → ≥ 0xFFFFF800 用 addi 负值
;;   lower 切片需零扩展 (or 会污染高位) → ≥ 0x7FFFF800 时补 slli/srli
(define (build-u64-pair rd use-reg upper-val lower-val)
  (define (load-upper r v)
    (if (>= v #xFFFFF800)
        `((addi ,r x0 ,(- v #x100000000)))   ; 符号扩展负值, 低 32 位 = v
        (let-values ([(hi lo) (split-hi-lo v)])
          (emit-hi-lo r hi lo))))
  (define (load-lower r v)
    (define s (if (>= v #xFFFFF800)
                  `((addi ,r x0 ,(- v #x100000000)))
                  (let-values ([(hi lo) (split-hi-lo v)])
                    (emit-hi-lo r hi lo))))
    (if (>= v #x7FFFF800)
        (append s `((slli ,r ,r 32) (srli ,r ,r 32)))
        s))
  `(,@(load-upper rd upper-val)
    (slli ,rd ,rd 32)
    ,@(load-lower use-reg lower-val)
    (or ,rd ,rd ,use-reg)))

;; JAL 指令的偏移范围：21位有符号 (±1MB)
(define (jal-offset? offset)
  (<= -1048576 offset 1048575))

;; ============================================================
;; 加载立即数
;; ============================================================

(define (load-immediate-number-32 rd imm)
  (if (fits-32? imm) (gen-32-load rd imm) #f))

(define (load-immediate-number-64 rd imm use-reg)
  (if (fits-64? imm) (gen-64-load rd imm use-reg) #f))

;; ── RV32 立即数构造 ──

(define (gen-32-load rd imm)
  (define raw    (bitwise-and imm #xFFFFFFFF))
  (define signed (sign-extend-32 raw))
  ;; 12位有符号范围内直接 addi，避免 hi=0x100000000 导致假的 lui
  (if (fits-signed-12? signed)
      `((addi ,rd x0 ,signed))
      (let-values ([(hi lo) (split-hi-lo raw)])
        (emit-hi-lo rd hi lo))))

;; ── RV64 立即数构造 ──
;;
;; RV64 lui 的 imm20 符号扩展到 64 位 (lui 0x80000 = -2^31), 所以 lui+addi
;; 只能正确表示: 12 位有符号值 / 负的 32 位符号扩展 / 正 32 位 ≤ 0x7FFFF7FF。
;; 其余 (正 32 位 ≥ 0x7FFFF800、任意 64 位) 用"切片 + 零扩展 + or"组合:
;;   切片 ≥ 0xFFFFF800 → addi 负值 (低 32 位相同)
;;   需要零扩展的切片 (or 会污染高位) → 补 slli/srli

(define (gen-64-load rd imm use-reg)
  (cond
    ;; Case 1: 12位有符号 — 单条 addi（必须优先，否则负数进入 Case 2 会生成假的 lui）
    [(fits-signed-12? imm)
     `((addi ,rd x0 ,imm))]
    ;; Case 2: 来自32位符号扩展 — lui + addi
    ;;   正 32 位值且 lui bit31=1 (imm ∈ 0x7FFFF800..0x7FFFFFFF) → lui 负扩展,
    ;;   补 slli/srli 零扩展
    [(fits-in-32-bit? imm)
     (let ([raw (bitwise-and imm #xFFFFFFFF)])
       (let-values ([(hi lo) (split-hi-lo raw)])
         (if (and (>= imm 0) (>= hi #x80000000))
             (append (emit-hi-lo rd hi lo)
                     `((slli ,rd ,rd 32) (srli ,rd ,rd 32)))
             (emit-hi-lo rd hi lo))))]
    ;; Case 3: 低32位全0 — build upper32 + slli 32
    ;;   upper 无符号化 (imm 为负时算术右移得 -1/-2^31 等, split-hi-lo 会崩或错)
    [(= (bitwise-and imm #xFFFFFFFF) 0)
     (let ([upper (bitwise-and (arithmetic-shift imm -32) #xFFFFFFFF)])
       (append (if (>= upper #xFFFFF800)
                   `((addi ,rd x0 ,(- upper #x100000000)))
                   (let-values ([(hi lo) (split-hi-lo upper)])
                     (emit-hi-lo rd hi lo)))
               `((slli ,rd ,rd 32))))]
    ;; Case 4: 完整64位 — 高/低32位分构建后OR
    [else
     (let ([hi32 (bitwise-and (arithmetic-shift imm -32) #xFFFFFFFF)]
           [lo32 (bitwise-and imm #xFFFFFFFF)])
       (build-u64-pair rd use-reg hi32 lo32))]))

;; 预测：加载这个 64 位立即数是否需要辅助寄存器（Case 4 才需要）
(define (needs-temp-register-for-64? imm)
  (and (exact-integer? imm)
       (not (fits-signed-12? imm))
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
    [(fits-signed-32? offset)
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
;; 分支扩展（偏移超出 B-type 12 位范围时）
;; ============================================================

;; B-type 偏移范围：12 位有符号，2 字节对齐 → [-4096, 4094]
(define (fits-branch-offset? offset)
  (and (<= -4096 offset 4094)
       (= (bitwise-and offset 1) 0)))

;; 分支条件取反
(define (branch-inverse mnemonic)
  (case mnemonic
    [(beq) 'bne]  [(bne) 'beq]
    [(blt) 'bge]  [(bge) 'blt]
    [(bltu) 'bgeu] [(bgeu) 'bltu]
    [else (error 'branch-inverse "unknown branch: ~a" mnemonic)]))

;; 展开过长分支：条件反转 + 短跳 + 长跳转
;; offset = target_pc - branch_pc
;; 返回 (values expanded-list byte-size)
;; 若偏移合法则返回 (values #f 4)
(define (expand-branch-if-needed mnemonic offset rs1 rs2 word-size)
  (if (fits-branch-offset? offset)
      (values #f 4)
      (let* ([inv         (branch-inverse mnemonic)]
             [jump-offset (- offset 4)]
             [jump-seq    (if (eq? word-size 'rv64)
                             (generate-64-jump 'zero jump-offset 'zero)
                             (generate-32-jump 'zero jump-offset))]
             [_           (unless jump-seq
                            (error 'expand-branch
                                   "cannot jump to offset ~a" offset))]
             [jump-size   (* 4 (length jump-seq))]
             [skip        (+ 4 jump-size)]
             [full        `((,inv ,skip ,rs1 ,rs2) ,@jump-seq)]
             [total-size  (+ 4 jump-size)])
        (values full total-size))))

;; ============================================================
(provide
 load-immediate-number-32
 load-immediate-number-64
 generate-32-jump
 generate-64-jump
 needs-temp-register-for-64?
 jump-to-absolute-32
 jump-to-absolute-64
 fits-branch-offset?
 branch-inverse
 expand-branch-if-needed)
