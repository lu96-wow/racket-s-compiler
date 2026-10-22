#lang racket/base

;; ============================================================
;; 最底层位组合原语
;;
;; 约定：
;;   - 一个 field 是一个函数：exact-integer? -> 非负整数位模式
;;   - field 接收的是“完整逻辑值”，不是已经移位过的片段
;;   - bit-range 负责从逻辑值中取位，并放到指令字的指定位置
;;   - combine 只负责把多个 field 的位模式 OR 起来
;;   - 固定字段不占用调用参数，由 make-instruction 单独接收
;;
;; 这一层不做名字推断，也不维护操作数表。
;; 某个字段叫什么、属于 raw 还是 rebuilt，由模块导入关系决定。
;; ============================================================

(require racket/list)

(provide bit
         bit-range
         bit-range-fixed
         combine
         bit-map
         make-instruction)

;; ------------------------------------------------------------
;; 校验
;; ------------------------------------------------------------

(define (check-source-index who what n)
  (unless (exact-nonnegative-integer? n)
    (raise-argument-error who "exact-nonnegative-integer?" n)))

(define (check-target-index who what n)
  (unless (exact-nonnegative-integer? n)
    (raise-argument-error who "exact-nonnegative-integer?" n))
  (when (> n 31)
    (raise-argument-error who "target bit index <= 31" n)))

(define (check-value who v)
  (unless (exact-integer? v)
    (raise-argument-error who "exact-integer?" v)))

(define (check-fields who fields)
  (unless (list? fields)
    (raise-argument-error who "list?" fields))
  (for ([f (in-list fields)])
    (unless (procedure? f)
      (raise-argument-error who "(listof procedure?)" fields))))

;; ------------------------------------------------------------
;; 单 bit 与连续 bit-range
;; ------------------------------------------------------------

;; (bit src dst) — 取逻辑值的第 src 位，放到指令字第 dst 位
(define (bit src dst)
  (check-source-index 'bit 'src src)
  (check-target-index 'bit 'dst dst)
  (lambda (value)
    (check-value 'bit value)
    (arithmetic-shift
     (bitwise-and (arithmetic-shift value (- src)) 1)
     dst)))

;; (bit-range src-lo src-hi dst-lo)
;; 取逻辑值的 [src-lo, src-hi]（闭区间），放到指令字 dst-lo 开始的连续位。
(define (bit-range src-lo src-hi dst-lo)
  (check-source-index 'bit-range 'src-lo src-lo)
  (check-source-index 'bit-range 'src-hi src-hi)
  (check-target-index 'bit-range 'dst-lo dst-lo)
  (unless (<= src-lo src-hi)
    (error 'bit-range "src-lo (~a) must be <= src-hi (~a)" src-lo src-hi))

  (define width (add1 (- src-hi src-lo)))
  (define mask (sub1 (arithmetic-shift 1 width)))
  (define dst-hi (+ dst-lo (sub1 width)))

  (when (> dst-hi 31)
    (error 'bit-range
           "target range [~a..~a] exceeds bit 31"
           dst-lo dst-hi))

  (lambda (value)
    (check-value 'bit-range value)
    (arithmetic-shift
     (bitwise-and (arithmetic-shift value (- src-lo)) mask)
     dst-lo)))

;; ------------------------------------------------------------
;; 固定字段
;; ------------------------------------------------------------

;; (bit-range-fixed lo hi value) — 常量字段，不消费调用参数
(define (bit-range-fixed lo hi value)
  (check-target-index 'bit-range-fixed 'lo lo)
  (check-target-index 'bit-range-fixed 'hi hi)
  (unless (<= lo hi)
    (error 'bit-range-fixed "lo (~a) must be <= hi (~a)" lo hi))
  (check-value 'bit-range-fixed value)
  (when (negative? value)
    (error 'bit-range-fixed "value must be non-negative, got ~a" value))

  (define width (add1 (- hi lo)))
  (define limit (arithmetic-shift 1 width))
  (when (>= value limit)
    (error 'bit-range-fixed
           "value ~a does not fit in ~a bit(s) [~a..~a]"
           value width lo hi))

  (define shifted (arithmetic-shift value lo))
  (lambda (_)
    shifted))

;; ------------------------------------------------------------
;; 组合
;; ------------------------------------------------------------

;; (combine f ...) — 所有 field 都接收同一个完整逻辑值，结果按位 OR
(define (combine . fields)
  (check-fields 'combine fields)
  (lambda (value)
    (for/fold ([word 0]) ([f (in-list fields)])
      (bitwise-ior word (f value)))))

;; (bit-map (src . dst) ...) — 把若干单个逻辑位映射到指令位
;; 用于 C 扩展这类逻辑位不连续的字段。
(define (bit-map . mappings)
  (for ([m (in-list mappings)])
    (unless (pair? m)
      (raise-argument-error 'bit-map "(listof (cons/c exact-nonnegative-integer? exact-nonnegative-integer?))" mappings)))
  (apply combine
         (for/list ([m (in-list mappings)])
           (bit (car m) (cdr m)))))

;; ------------------------------------------------------------
;; 指令组合
;; ------------------------------------------------------------

;; (make-instruction operands fixed)
;;   operands : (listof procedure?) — 按源码顺序接收调用参数
;;   fixed    : (listof procedure?) — 常量字段，不接收参数
;;
;; 固定字段显式分离，避免旧实现中“固定字段必须放在参数列表末尾”的
;; 隐式约束。
(define (make-instruction operands fixed)
  (check-fields 'make-instruction operands)
  (check-fields 'make-instruction fixed)

  (lambda args
    (unless (= (length args) (length operands))
      (error 'make-instruction
             "expected ~a operand(s), got ~a: ~e"
             (length operands) (length args) args))

    (define fixed-word
      (for/fold ([word 0]) ([f (in-list fixed)])
        (bitwise-ior word (f 0))))

    (for/fold ([word fixed-word])
              ([f (in-list operands)]
               [arg (in-list args)])
      (bitwise-ior word (f arg)))))
