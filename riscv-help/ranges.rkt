#lang racket/base

;; ============================================================
;; 范围判断与 hi/lo 拆分
;;
;; 这一层只做纯数值判断，不生成指令，也不关心符号/重定位。
;; ============================================================

(require racket/list)

;; ------------------------------------------------------------
;; 基本有符号/无符号范围
;; ------------------------------------------------------------

(define (fits-signed? bits value)
  (and (exact-integer? value)
       (let ([bound (arithmetic-shift 1 (sub1 bits))])
         (<= (- bound) value (sub1 bound)))))

(define (fits-unsigned? bits value)
  (and (exact-integer? value)
       (<= 0 value (sub1 (arithmetic-shift 1 bits)))))

(define (fits-s12? value)
  (fits-signed? 12 value))

(define (fits-s12-even? value)
  (and (fits-s12? value) (even? value)))

;; C.J / C.JAL: ±2KiB, bit0 = 0
(define (fits-cjump? offset)
  (fits-s12-even? offset))

;; B-type: ±4KiB, bit0 = 0
(define (fits-branch? offset)
  (and (fits-signed? 13 offset)
       (even? offset)))

;; C.BEQZ / C.BNEZ: ±256B, bit0 = 0
(define (fits-cbranch? offset)
  (and (fits-signed? 9 offset)
       (even? offset)))

;; JAL: ±1MiB, bit0 = 0
(define (fits-jal? offset)
  (and (fits-signed? 21 offset)
       (even? offset)))

;; JALR 的 12 位立即数
(define (fits-jalr12? offset)
  (fits-s12? offset))

(define (fits-32? value)
  (or (fits-signed? 32 value)
      (fits-unsigned? 32 value)))

(define (fits-64? value)
  (or (fits-signed? 64 value)
      (fits-unsigned? 64 value)))

;; ------------------------------------------------------------
;; 符号扩展 / hi20 + lo12
;; ------------------------------------------------------------

(define (sign-extend bits value)
  (define modulus (arithmetic-shift 1 bits))
  (define u (bitwise-and value (sub1 modulus)))
  (if (>= u (arithmetic-shift 1 (sub1 bits)))
      (- u modulus)
      u))

;; 返回两个值：
;;   hi20 : 可直接传给 lui/auipc 的 20 位字段值
;;   lo12 : 可直接传给 addi/jalr 的有符号 12 位值
;;
;; 满足 value = (sign_extend_20(hi20) << 12) + lo12
(define (split-hi-lo value)
  (define lo (sign-extend 12 (bitwise-and value #xFFF)))
  (define hi (arithmetic-shift (+ value (- lo)) -12))
  (values (bitwise-and hi #xFFFFF) lo))

;; ------------------------------------------------------------
;; 绝对量：LUI + ADDI
;; ------------------------------------------------------------

;; RV64 下 LUI 会把 32 位结果符号扩展到 64 位。
;; 因此 LUI+ADDI 能精确表示的绝对量是：
;;   [-2^31 - 2048, 2^31 - 2049]
;; 而不是整个 signed-32。
(define (fits-lui-addi? value word-size)
  (case word-size
    [(rv32)
     (fits-32? value)]
    [(rv64)
     (and (exact-integer? value)
          (let-values ([(hi lo) (split-hi-lo value)])
            (= value
               (+ (arithmetic-shift (sign-extend 20 hi) 12)
                  lo))))]
    [else
     (error 'fits-lui-addi? "unknown word size: ~a" word-size)]))

(define (fits-lui? value word-size)
  (and (fits-lui-addi? value word-size)
       (zero? (bitwise-and value #xFFF))))

;; RV64：正的 32 位值，但不在 LUI+ADDI 窗口内。
;; 需要先按 32 位加载，再零扩展。
(define (fits-zext32? value)
  (and (exact-integer? value)
       (<= #x7FFFF800 value #xFFFFFFFF)))

(define (fits-low32-zero? value)
  (and (exact-integer? value)
       (zero? (bitwise-and value #xFFFFFFFF))))

;; ------------------------------------------------------------
;; PC-relative：AUIPC + ADDI / AUIPC + JALR
;; ------------------------------------------------------------

(define (fits-pcrel-hi-lo? delta)
  (and (exact-integer? delta)
       (let-values ([(hi lo) (split-hi-lo delta)])
         (= delta
            (+ (arithmetic-shift (sign-extend 20 hi) 12)
               lo)))))

(define (fits-auipc-pair? delta word-size)
  (case word-size
    [(rv32)
     (fits-32? delta)]
    [(rv64)
     (fits-pcrel-hi-lo? delta)]
    [else
     (error 'fits-auipc-pair? "unknown word size: ~a" word-size)]))

(provide fits-signed?
         fits-unsigned?
         fits-s12?
         fits-s12-even?
         fits-cjump?
         fits-branch?
         fits-cbranch?
         fits-jal?
         fits-jalr12?
         fits-32?
         fits-64?
         sign-extend
         split-hi-lo
         fits-lui-addi?
         fits-lui?
         fits-zext32?
         fits-low32-zero?
         fits-pcrel-hi-lo?
         fits-auipc-pair?)
