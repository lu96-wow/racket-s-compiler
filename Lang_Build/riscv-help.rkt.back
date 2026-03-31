#lang racket

(require "number.rkt")

;; 算术右移
(define (ash-right n shift)
  (arithmetic-shift n (- shift)))

;; Helper for RV64
(define (fits-in-32-bit? n)
  (let ([low32 (bitwise-and n #xFFFFFFFF)])
    (let ([sext (if (>= low32 #x80000000)
                    (- low32 #x100000000)
                    low32)])
      (= n sext))))

;; RV32: auto choose signed/unsigned check
(define (load-immediate-number-32 rd imm)
  (cond
    [(not (exact-integer? imm))
     #f]

    ;; Choose check based on sign
    [(< imm 0)
     (if (> (min-signed-bits imm) 32)
         #f
         (generate-32-instructions rd imm))]

    [else ; imm >= 0
     (if (> (min-unsigned-bits imm) 32)
         #f
         (generate-32-instructions rd imm))]))

;; RV64: auto choose signed/unsigned check
(define (load-immediate-number-64 rd imm use-reg)
  (cond
    [(not (exact-integer? imm))
     #f]

    [(< imm 0)
     (if (> (min-signed-bits imm) 64)
         #f
         (generate-64-instructions rd imm use-reg))]

    [else ; imm >= 0
     (if (> (min-unsigned-bits imm) 64)
         #f
         (generate-64-instructions rd imm use-reg))]))

;; Shared instruction generators

(define (generate-32-instructions rd imm)
  (let* ([imm32 (bitwise-and imm #xFFFFFFFF)]
         [signed-imm32 (if (>= imm32 #x80000000)
                           (- imm32 #x100000000)
                           imm32)])
    (cond
      [(and (>= signed-imm32 -2048) (<= signed-imm32 2047))
       `((addi ,rd x0 ,signed-imm32))]
      [(low12-zero? imm32)
       (let ([hi20 (ash-right imm32 12)])
         `((lui ,rd ,hi20)))]
      [else
       (let* ([lo12 (low12-signed signed-imm32)]
              [hi20 (ash-right (+ imm32 #x800) 12)])
         `((lui ,rd ,hi20)
           (addi ,rd ,rd ,lo12)))])))

(define (generate-64-instructions rd imm use-reg)
  (cond
    ;; Case 1: 12-bit signed
    [(and (>= imm -2048) (<= imm 2047))
     `((addi ,rd x0 ,imm))]

    ;; Case 2: sign-extended from 32 bits
    [(fits-in-32-bit? imm)
     (let* ([imm32 (bitwise-and imm #xFFFFFFFF)]
            [lo12 (low12-signed imm)]
            [hi20 (ash-right (+ imm32 #x800) 12)])
       `((lui ,rd ,hi20)
         (addiw ,rd ,rd ,lo12)))]

    ;; Case 3: low 32 bits are zero (and imm != 0, since 0 is caught above)
    [(= (bitwise-and imm #xFFFFFFFF) 0)
     (let* ([upper32 (ash-right imm 32)]  ; high 32 bits
            [lo12 (low12-signed upper32)]
            [hi20 (if (low12-zero? upper32)
                      (ash-right upper32 12)
                      (ash-right (+ upper32 #x800) 12))])
       (append
        (if (low12-zero? upper32)
            `((lui ,rd ,hi20))
            `((lui ,rd ,hi20) (addi ,rd ,rd ,lo12)))
        `((slli ,rd ,rd 32))))]

    ;; Case 4: full 64-bit constant
    [else
     (let* ([high32 (ash-right imm 32)]
            [low32  (bitwise-and imm #xFFFFFFFF)]
            [high-lo12 (low12-signed high32)]
            [high-hi20 (if (low12-zero? high32)
                           (ash-right high32 12)
                           (ash-right (+ high32 #x800) 12))]
            [low-lo12 (low12-signed low32)]
            [low-hi20  (if (low12-zero? low32)
                           (ash-right low32 12)
                           (ash-right (+ low32 #x800) 12))])
       (append
        (if (low12-zero? high32)
            `((lui ,rd ,high-hi20))
            `((lui ,rd ,high-hi20) (addi ,rd ,rd ,high-lo12)))
        `((slli ,rd ,rd 32))
        (if (low12-zero? low32)
            `((lui ,use-reg ,low-hi20))
            `((lui ,use-reg ,low-hi20) (addi ,use-reg ,use-reg ,low-lo12)))
        `((or ,rd ,rd ,use-reg))))]))

(define (needs-temp-register-for-64? imm)
  (cond
    [(not (exact-integer? imm)) #t]
    [(and (>= imm -2048) (<= imm 2047)) #f]
    [(fits-in-32-bit? imm) #f]
    [(= (bitwise-and imm #xFFFFFFFF) 0) #f]
    [else #t]))

;; 判断偏移是否适合 JAL（±1MB）
(define (jal-offset? offset)
  (and (>= offset -1048576) (<= offset 1048575)))

(define (generate-32-jump rd offset)
  (cond
    [(jal-offset? offset)
     `((jal ,rd ,offset))]

    [else
     (let* ([off32 (bitwise-and offset #xFFFFFFFF)]
            [signed-off32 (if (>= off32 #x80000000)
                              (- off32 #x100000000)
                              off32)])
       (if (low12-zero? signed-off32)
           (let ([hi20 (ash-right off32 12)])
             `((auipc ,rd ,hi20)
               (jalr ,rd ,rd 0)))
           (let* ([lo12 (low12-signed signed-off32)]
                  [hi20 (ash-right (+ off32 #x800) 12)])
             `((auipc ,rd ,hi20)
               (jalr ,rd ,rd ,lo12)))))]))

(define (generate-64-jump rd offset use-reg)
  (cond
    [(jal-offset? offset)
     `((jal ,rd ,offset))]

    [(and (>= offset (- (expt 2 31))) (< offset (expt 2 31)))

     (let* ([off32 (bitwise-and offset #xFFFFFFFF)]
            [signed-off32 (if (>= off32 #x80000000)
                              (- off32 #x100000000)
                              off32)])
       (if (low12-zero? signed-off32)
           (let ([hi20 (ash-right off32 12)])
             `((auipc ,rd ,hi20)
               (jalr ,rd ,rd 0)))
           (let* ([lo12 (low12-signed signed-off32)]
                  [hi20 (ash-right (+ off32 #x800) 12)])
             `((auipc ,rd ,hi20)
               (jalr ,rd ,rd ,lo12)))))]

    ;; 真正的大偏移（>32位）：用完整 64-bit 构造
    [else
     (let* ([high32 (ash-right offset 32)]
            [low32  (bitwise-and offset #xFFFFFFFF)]
            [high-lo12 (low12-signed high32)]
            [high-hi20 (if (low12-zero? high32)
                           (ash-right high32 12)
                           (ash-right (+ high32 #x800) 12))]
            [low-lo12 (low12-signed low32)]
            [low-hi20  (if (low12-zero? low32)
                           (ash-right low32 12)
                           (ash-right (+ low32 #x800) 12))])
       (append
        (if (low12-zero? high32)
            `((auipc ,rd ,high-hi20))
            `((auipc ,rd ,high-hi20) (addi ,rd ,rd ,high-lo12)))
        `((slli ,rd ,rd 32))
        (if (low12-zero? low32)
            `((lui ,use-reg ,low-hi20))
            `((lui ,use-reg ,low-hi20) (addi ,use-reg ,use-reg ,low-lo12)))
        `((or ,rd ,rd ,use-reg)
          (jalr ,rd ,rd 0))))]))

;; 跳转到绝对地址（32 位）
;; rd: 返回地址寄存器（jalr 的 rd）
;; addr-reg: 存放绝对地址的寄存器（jalr 的 rs1）
(define (jump-to-absolute-32 rd addr-reg addr)
  (let ([load-insns (load-immediate-number-32 addr-reg addr)])
    (if load-insns
        (append load-insns `((jalr ,rd ,addr-reg 0)))
        #f)))

;; 跳转到绝对地址（64 位）
;; rd: 返回地址寄存器
;; addr-reg: 存放绝对地址的寄存器（jalr 的 rs1）
;; temp-reg: 64 位立即数构造所需的临时寄存器（可与 addr-reg 不同）
(define (jump-to-absolute-64 rd addr-reg temp-reg addr)
  (let ([load-insns (load-immediate-number-64 addr-reg addr temp-reg)])
    (if load-insns
        (append load-insns `((jalr ,rd ,addr-reg 0)))
        #f)))

(provide
 ;;加载立即数
 load-immediate-number-32
 load-immediate-number-64
 ;;相对跳转
 generate-32-jump
 generate-64-jump
 ;;判断是否需要额外辅助寄存器
 needs-temp-register-for-64?
 ;;绝对地址跳转
 jump-to-absolute-32
 jump-to-absolute-64
 )