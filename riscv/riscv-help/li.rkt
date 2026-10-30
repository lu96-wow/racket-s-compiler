#lang racket/base

;; ============================================================
;; li：加载绝对常量
;;
;; 每种范围一个叶子函数，最后由 expand-li 按精确范围组合。
;; 叶子函数严格检查边界；expand-li 是范围分派，不是失败回退。
;; 对外入口是 li / li-size。
;; ============================================================

(require racket/list
         racket/string
         "ranges.rkt"
         "registers.rkt")

;; ------------------------------------------------------------
;; 内部：按 32 位 bit pattern 加载
;;
;; 这个函数不要求值属于某个范围，只负责把低 32 位放进 rd。
;; RV64 下 LUI 的符号扩展可能让结果在高 32 位全 1，这正好可以
;; 用于“先按 32 位加载，再零扩展”的情况。
;; ------------------------------------------------------------

(define (li-32-bits rd value)
  (define raw (bitwise-and value #xFFFFFFFF))
  (define signed (sign-extend 32 raw))
  (cond
    [(fits-s12? signed)
     (list (list 'addi rd 'x0 signed))]
    [else
     (define-values (hi lo) (split-hi-lo raw))
     (cond
       [(zero? lo)
        (list (list 'lui rd hi))]
       [else
        (list (list 'lui rd hi)
              (list 'addi rd rd lo))])]))

;; ------------------------------------------------------------
;; 叶子函数
;; ------------------------------------------------------------

;; [-2048, 2047]
(define (li-s12 rd value)
  (unless (fits-s12? value)
    (error 'li-s12 "value ~a is outside signed 12-bit range" value))
  (list (list 'addi rd 'x0 value)))

;; 低 12 位为 0；LUI 单独完成
(define (li-lui rd value #:word-size [word-size 'rv64])
  (unless (fits-lui? value word-size)
    (error 'li-lui "value ~a is not a LUI-representable value for ~a"
           value word-size))
  (define-values (hi _lo) (split-hi-lo value))
  (list (list 'lui rd hi)))

;; 一般 LUI + ADDI
(define (li-lui-addi rd value #:word-size [word-size 'rv64])
  (unless (fits-lui-addi? value word-size)
    (error 'li-lui-addi "value ~a is not a LUI+ADDI-representable value for ~a"
           value word-size))
  (define-values (hi lo) (split-hi-lo value))
  (cond
    [(zero? lo)
     (list (list 'lui rd hi))]
    [else
     (list (list 'lui rd hi)
           (list 'addi rd rd lo))]))

;; RV64 专用：LUI + ADDIW
;;
;; ADDIW 会把 32 位加法结果重新符号扩展，因此可以精确得到
;; 那些 LUI+ADDI 会被 LUI 符号扩展破坏的 signed-32 值。
(define (li-lui-addiw rd value #:word-size [word-size 'rv64])
  (unless (eq? word-size 'rv64)
    (error 'li-lui-addiw "ADDIW is only available on RV64"))
  (unless (fits-lui-addiw? value word-size)
    (error 'li-lui-addiw
           "value ~a is not a LUI+ADDIW-representable value for ~a"
           value word-size))
  (define-values (hi lo) (split-hi-lo value))
  (cond
    [(zero? hi)
     (list (list 'addiw rd 'x0 lo))]
    [(zero? lo)
     (list (list 'lui rd hi))]
    [else
     (list (list 'lui rd hi)
           (list 'addiw rd rd lo))]))

;; RV64：正的 32 位值，但不在 LUI+ADDI 窗口内。
;; 先按 32 位加载，再零扩展。
(define (li-zext32 rd value)
  (unless (fits-zext32? value)
    (error 'li-zext32 "value ~a is outside zext32 range" value))
  (append (li-32-bits rd value)
          (list (list 'slli rd rd 32)
                (list 'srli rd rd 32))))

;; RV64：low32(value) = 0
;; value = high32 << 32
(define (li-low32-zero rd value)
  (unless (and (fits-64? value)
               (fits-low32-zero? value))
    (error 'li-low32-zero "value ~a is not a valid low32-zero 64-bit value" value))
  (define high32 (arithmetic-shift value -32))
  (append (li-32-bits rd high32)
          (list (list 'slli rd rd 32))))

;; 任意 64 位值。
;;
;; 采用 GAS load_const 的基本思路：
;;   1. 先拆出有符号低 12 位 lower；
;;   2. 从 bit12 开始找到 upper 的最低有效位，确定 shift；
;;   3. 递归加载 upper >> shift；
;;   4. 恢复 shift，再加回 lower。
;;
;; 这样最坏只需要 8 条左右的指令，而不是固定按 6 个 12 位块展开。
;; #:scratch 暂时保留给未来优化；当前算法不需要临时寄存器。
(define (li-general64 rd value #:scratch [scratch #f])
  (unless (fits-64? value)
    (error 'li-general64 "value ~a does not fit in 64 bits" value))
  (when (zero-register? scratch)
    (error 'li-general64 "scratch cannot be zero"))

  (define raw
    (sign-extend 64 (bitwise-and value #xFFFFFFFFFFFFFFFF)))

  (cond
    ;; 直接调用叶子函数时也保持可用：signed-32 交给正常分派。
    [(fits-signed? 32 raw)
     (expand-li rd raw #:word-size 'rv64 #:scratch scratch)]
    [else
     (define lower (sign-extend 12 raw))
     (define upper (- raw lower))
     (cond
       [(zero? upper)
        (li-s12 rd lower)]
       [else
        (define shift
          (for/first ([s (in-range 12 64)]
                      #:when (odd? (arithmetic-shift upper (- s))))
            s))
        (unless shift
          (error 'li-general64
                 "could not find a shift amount for value ~a"
                 value))
        (define shifted (arithmetic-shift upper (- shift)))
        (append
         (expand-li rd shifted #:word-size 'rv64 #:scratch scratch)
         (list (list 'slli rd rd shift))
         (if (zero? lower)
             '()
             (list (list 'addi rd rd lower))))])]))

;; ------------------------------------------------------------
;; 组合
;; ------------------------------------------------------------

(define (normalize-word value word-size)
  (case word-size
    [(rv32)
     (unless (fits-32? value)
       (error 'expand-li "value ~a does not fit in RV32" value))
     (sign-extend 32 (bitwise-and value #xFFFFFFFF))]
    [(rv64)
     (unless (fits-64? value)
       (error 'expand-li "value ~a does not fit in RV64" value))
     (sign-extend 64 (bitwise-and value #xFFFFFFFFFFFFFFFF))]
    [else
     (error 'expand-li "unknown word size: ~a" word-size)]))

(define (expand-li rd value
                   #:word-size [word-size 'rv64]
                   #:scratch [scratch #f])
  ;; #:scratch 目前只对某些展开策略有意义；li 本身的 GAS 风格算法不需要。
  (define v (normalize-word value word-size))
  (case word-size
    [(rv32)
     (cond
       [(fits-s12? v)
        (li-s12 rd v)]
       [(zero? (bitwise-and v #xFFF))
        (li-lui rd v #:word-size 'rv32)]
       [else
        (li-lui-addi rd v #:word-size 'rv32)])]
    [(rv64)
     (cond
       [(fits-s12? v)
        (li-s12 rd v)]
       [(fits-lui-addi? v 'rv64)
        (if (fits-lui? v 'rv64)
            (li-lui rd v #:word-size 'rv64)
            (li-lui-addi rd v #:word-size 'rv64))]
       ;; signed-32 但 LUI+ADDI 不精确：用 ADDIW 修正符号扩展。
       [(fits-signed? 32 v)
        (li-lui-addiw rd v #:word-size 'rv64)]
       [(fits-zext32? v)
        (li-zext32 rd v)]
       [(fits-low32-zero? v)
        (li-low32-zero rd v)]
       [else
        (li-general64 rd v #:scratch scratch)])]))

;; ------------------------------------------------------------
;; 对外的自动入口
;; ------------------------------------------------------------

;; 通用常量/绝对地址加载。自动选择具体叶子形式。
(define (li rd value #:word-size [word-size 'rv64])
  (expand-li rd value #:word-size word-size))

(define (generated-instruction-size instruction)
  (define mnemonic (car instruction))
  (if (string-prefix? (symbol->string mnemonic) "c.")
      2
      4))

(define (generated-instructions-size instructions)
  (for/sum ([instruction (in-list instructions)])
    (generated-instruction-size instruction)))

;; 返回 li 展开后的字节数。
(define (li-size value #:word-size [word-size 'rv64])
  (generated-instructions-size
   (expand-li 'a0 value #:word-size word-size)))

(provide li-s12
         li-lui
         li-lui-addi
         li-lui-addiw
         li-zext32
         li-low32-zero
         li-general64
         expand-li
         li
         li-size)
