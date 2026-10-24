#lang racket/base

;; ============================================================
;; li：加载绝对常量
;;
;; 每种范围一个叶子函数，最后由 expand-li 组合。
;; 叶子函数只负责生成指令；范围选择由 dispatcher 负责。
;; ============================================================

(require racket/list
         "instruction.rkt"
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
     (list (I 'addi rd 'x0 signed))]
    [else
     (define-values (hi lo) (split-hi-lo raw))
     (cond
       [(zero? lo)
        (list (I 'lui rd hi))]
       [else
        (list (I 'lui rd hi)
              (I 'addi rd rd lo))])]))

;; ------------------------------------------------------------
;; 叶子函数
;; ------------------------------------------------------------

;; [-2048, 2047]
(define (li-s12 rd value)
  (unless (fits-s12? value)
    (error 'li-s12 "value ~a is outside signed 12-bit range" value))
  (list (I 'addi rd 'x0 value)))

;; 低 12 位为 0；LUI 单独完成
(define (li-lui rd value #:word-size [word-size 'rv64])
  (unless (fits-lui? value word-size)
    (error 'li-lui "value ~a is not a LUI-representable value for ~a"
           value word-size))
  (define-values (hi _lo) (split-hi-lo value))
  (list (I 'lui rd hi)))

;; 一般 LUI + ADDI
(define (li-lui-addi rd value #:word-size [word-size 'rv64])
  (unless (fits-lui-addi? value word-size)
    (error 'li-lui-addi "value ~a is not a LUI+ADDI-representable value for ~a"
           value word-size))
  (define-values (hi lo) (split-hi-lo value))
  (cond
    [(zero? lo)
     (list (I 'lui rd hi))]
    [else
     (list (I 'lui rd hi)
           (I 'addi rd rd lo))]))

;; RV64：正的 32 位值，但不在 LUI+ADDI 窗口内。
;; 先按 32 位加载，再零扩展。
(define (li-zext32 rd value)
  (unless (fits-zext32? value)
    (error 'li-zext32 "value ~a is outside zext32 range" value))
  (append (li-32-bits rd value)
          (list (I 'slli rd rd 32)
                (I 'srli rd rd 32))))

;; RV64：low32(value) = 0
;; value = high32 << 32
(define (li-low32-zero rd value)
  (unless (and (fits-64? value)
               (fits-low32-zero? value))
    (error 'li-low32-zero "value ~a is not a valid low32-zero 64-bit value" value))
  (define high32 (arithmetic-shift value -32))
  (append (li-32-bits rd high32)
          (list (I 'slli rd rd 32))))

;; 任意 64 位值
;; 有 scratch 时用 high32/low32 拼接；
;; 没有 scratch 时用 6 个 12 位块。
(define (li-general64 rd value #:scratch [scratch #f])
  (unless (fits-64? value)
    (error 'li-general64 "value ~a does not fit in 64 bits" value))
  (when (zero-register? scratch)
    (error 'li-general64 "scratch cannot be zero"))

  (define raw (bitwise-and value #xFFFFFFFFFFFFFFFF))
  (define low32 (bitwise-and raw #xFFFFFFFF))
  (define high32 (arithmetic-shift raw -32))

  (if (and scratch (not (same-register? scratch rd)))
      (append
       (li-32-bits rd high32)
       (list (I 'slli rd rd 32))
       (li-32-bits scratch low32)
       ;; OR 要求 scratch 是零扩展的 64 位值
       (if (>= low32 #x80000000)
           (list (I 'slli scratch scratch 32)
                 (I 'srli scratch scratch 32))
           '())
       (list (I 'or rd rd scratch)))
      (let* ([chunks (12-bit-chunks raw)]
             [top (car chunks)])
        (append
         (list (I 'addi rd 'x0 top))
         (append-map
          (lambda (chunk)
            (list (I 'slli rd rd 12)
                  (I 'addi rd rd chunk)))
          (cdr chunks))))))

;; 将 64 位模式拆成 6 个有符号 12 位块（返回 high -> low）。
(define (12-bit-chunks value)
  (define digits
    (for/list ([i (in-range 6)])
      (bitwise-and (arithmetic-shift value (- (* 12 i))) #xFFF)))
  (define-values (chunks _carry)
    (for/fold ([acc '()] [carry 0]) ([d (in-list digits)])
      (define total (+ d carry))
      (define s (if (>= total #x800) (- total #x1000) total))
      (define next-carry (if (>= total #x800) 1 0))
      (values (cons s acc) next-carry)))
  chunks)

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
       [(fits-zext32? v)
        (li-zext32 rd v)]
       [(fits-low32-zero? v)
        (li-low32-zero rd v)]
       [else
        (li-general64 rd v #:scratch scratch)])]))

(provide li-s12
         li-lui
         li-lui-addi
         li-zext32
         li-low32-zero
         li-general64
         expand-li)
