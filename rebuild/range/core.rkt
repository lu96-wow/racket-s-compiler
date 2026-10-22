#lang racket/base

;; ============================================================
;; range 核心：逻辑位域 ↔ 指令位
;;
;; 设计要点：
;;   1. slice 是纯数据：逻辑值位 [value-lo, value-hi] → 指令位 [target-lo, ...]
;;   2. 一个 field 可以由多个 slice 组成（S/B/J 型立即数）
;;   3. field 的 encode / decode 严格互逆，便于测试与反汇编
;;   4. 对齐产生的隐式零位（如 bimm12 的 bit0）不占 slice
;;   5. 范围、对齐、位覆盖在构造 field 时一次性校验
;;
;; 与旧实现相比：
;;   - 不再用宏生成不透明闭包，field 是可检查的数据
;;   - 不再把“检查”和“移位”分散在两层
;;   - 立即数不再拆成 imm12hi / imm12lo 之类字符串特例
;; ============================================================

(require racket/list)

;; ------------------------------------------------------------
;; slice：逻辑位 → 指令位
;; ------------------------------------------------------------

(struct slice (value-lo value-hi target-lo)
  #:transparent
  #:guard
  (lambda (value-lo value-hi target-lo struct-name)
    (unless (exact-nonnegative-integer? value-lo)
      (raise-argument-error struct-name "exact-nonnegative-integer?" value-lo))
    (unless (exact-nonnegative-integer? value-hi)
      (raise-argument-error struct-name "exact-nonnegative-integer?" value-hi))
    (unless (<= value-lo value-hi)
      (error struct-name
             "value-lo (~a) must be <= value-hi (~a)"
             value-lo value-hi))
    (unless (exact-nonnegative-integer? target-lo)
      (raise-argument-error struct-name "exact-nonnegative-integer?" target-lo))
    (values value-lo value-hi target-lo)))

(define (slice-width s)
  (add1 (- (slice-value-hi s) (slice-value-lo s))))

(define (slice-target-hi s)
  (+ (slice-target-lo s) (sub1 (slice-width s))))

;; ------------------------------------------------------------
;; field：一个逻辑操作数字段
;; ------------------------------------------------------------

(struct field (name slices signed? align)
  #:transparent
  #:guard
  (lambda (name slices signed? align struct-name)
    (validate-field! struct-name name slices signed? align)
    (values name slices signed? align)))

(define (power-of-two? n)
  (and (exact-positive-integer? n)
       (zero? (bitwise-and n (sub1 n)))))

(define (make-field name slices #:signed? [signed? #f] #:align [align 1])
  (field name slices signed? align))

;; align=1 → 0 个隐式零位；align=2 → 1 个；align=4 → 2 个
(define (implicit-zero-bits align)
  (integer-length (sub1 align)))

(define (field-width f)
  (for/fold ([w 0]) ([s (in-list (field-slices f))])
    (max w (add1 (slice-value-hi s)))))

(define (field-implicit-bits f)
  (implicit-zero-bits (field-align f)))

(define (field-target-bits f)
  (sort
   (for*/list ([s (in-list (field-slices f))]
               [bit (in-range (slice-width s))])
     (+ (slice-target-lo s) bit))
   <))

(define (field-min f)
  (define w (field-width f))
  (if (field-signed? f)
      (- (arithmetic-shift 1 (sub1 w)))
      0))

(define (field-max f)
  (define w (field-width f))
  (define raw
    (if (field-signed? f)
        (sub1 (arithmetic-shift 1 (sub1 w)))
        (sub1 (arithmetic-shift 1 w))))
  (define align (field-align f))
  (- raw (modulo raw align)))

(define (validate-field! who name slices signed? align)
  (unless (symbol? name)
    (raise-argument-error who "symbol?" name))
  (unless (and (list? slices) (pair? slices))
    (raise-argument-error who "(non-empty-listof slice?)" slices))
  (for ([s (in-list slices)])
    (unless (slice? s)
      (raise-argument-error who "(listof slice?)" slices)))
  (unless (boolean? signed?)
    (raise-argument-error who "boolean?" signed?))
  (unless (power-of-two? align)
    (raise-argument-error who "power-of-two?" align))

  (define implicit (implicit-zero-bits align))
  (define width (for/fold ([w 0]) ([s (in-list slices)])
                  (max w (add1 (slice-value-hi s)))))

  (unless (> width implicit)
    (error who "field ~a has no encoded bits" name))

  ;; 1. 隐式零位不能出现在 slice 中
  (for ([s (in-list slices)])
    (when (< (slice-value-lo s) implicit)
      (error who
             "field ~a slice [~a..~a] overlaps implicit zero bit(s) of align ~a"
             name (slice-value-lo s) (slice-value-hi s) align)))

  ;; 2. 逻辑位必须从 implicit 到 width-1 恰好覆盖一次
  (for ([bit (in-range implicit width)])
    (define covering
      (for/list ([s (in-list slices)]
                 #:when (<= (slice-value-lo s) bit (slice-value-hi s)))
        s))
    (cond
      [(null? covering)
       (error who "field ~a leaves logical bit ~a unmapped" name bit)]
      [(> (length covering) 1)
       (error who "field ~a maps logical bit ~a more than once" name bit)]))

  ;; 3. 指令位不能重叠，且必须落在 32 位字内
  (for ([s (in-list slices)])
    (when (> (slice-target-hi s) 31)
      (error who
             "field ~a slice targets bits [~a..~a], beyond 31"
             name (slice-target-lo s) (slice-target-hi s))))
  (define targets
    (for*/list ([s (in-list slices)]
                [bit (in-range (slice-width s))])
      (+ (slice-target-lo s) bit)))
  (unless (= (length targets) (length (remove-duplicates targets)))
    (error who "field ~a has overlapping instruction-bit targets" name)))

;; ------------------------------------------------------------
;; encode / decode
;; ------------------------------------------------------------

(define (bit-mask width)
  (sub1 (arithmetic-shift 1 width)))

;; ------------------------------------------------------------
;; 最基本的 range 操作
;;
;; slice 是数据；slice-encode / slice-decode 是最底层的函数。
;; slice->encoder / slice->decoder 只是把它变成 lambda，
;; 方便上层直接当函数组合使用。
;; ------------------------------------------------------------

(define (slice-encode s value)
  (arithmetic-shift
   (bitwise-and value (bit-mask (slice-width s)))
   (slice-target-lo s)))

(define (slice-decode s word)
  (bitwise-and
   (arithmetic-shift word (- (slice-target-lo s)))
   (bit-mask (slice-width s))))

(define (slice->encoder s)
  (lambda (value)
    (slice-encode s value)))

(define (slice->decoder s)
  (lambda (word)
    (slice-decode s word)))

(define (field-expectation f)
  (define range (format "[~a, ~a]" (field-min f) (field-max f)))
  (define align (field-align f))
  (if (= align 1)
      (format "field ~a expects an exact integer in ~a" (field-name f) range)
      (format "field ~a expects an exact integer in ~a aligned to ~a"
              (field-name f) range align)))

(define (encode-field f v)
  (unless (exact-integer? v)
    (error 'encode-field "~a, got ~e" (field-expectation f) v))
  (define align (field-align f))
  (unless (zero? (modulo v align))
    (error 'encode-field
           "~a, got ~a (not aligned to ~a)"
           (field-expectation f) v align))
  (define lo (field-min f))
  (define hi (field-max f))
  (unless (<= lo v hi)
    (error 'encode-field
           "~a, got ~a (out of range)"
           (field-expectation f) v))

  (define width (field-width f))
  (define bits (if (negative? v)
                   (+ v (arithmetic-shift 1 width))
                   v))

  (for/fold ([word 0]) ([s (in-list (field-slices f))])
    (define chunk
      (arithmetic-shift bits (- (slice-value-lo s))))
    (bitwise-ior word (slice-encode s chunk))))

(define (decode-field f word)
  (unless (exact-nonnegative-integer? word)
    (raise-argument-error 'decode-field "exact-nonnegative-integer?" word))

  (define raw
    (for/fold ([value 0]) ([s (in-list (field-slices f))])
      (bitwise-ior value
                   (arithmetic-shift (slice-decode s word)
                                     (slice-value-lo s)))))

  (define width (field-width f))
  (if (and (field-signed? f)
           (bitwise-bit-set? raw (sub1 width)))
      (- raw (arithmetic-shift 1 width))
      raw))

;; ------------------------------------------------------------
;; 固定字段：没有参数，值直接写入指令位
;; ------------------------------------------------------------

(struct constant-field (name lo hi value)
  #:transparent
  #:guard
  (lambda (name lo hi value struct-name)
    (unless (symbol? name)
      (raise-argument-error struct-name "symbol?" name))
    (unless (exact-nonnegative-integer? lo)
      (raise-argument-error struct-name "exact-nonnegative-integer?" lo))
    (unless (exact-nonnegative-integer? hi)
      (raise-argument-error struct-name "exact-nonnegative-integer?" hi))
    (unless (<= lo hi)
      (error struct-name "lo (~a) must be <= hi (~a)" lo hi))
    (when (> hi 31)
      (error struct-name "hi (~a) must be <= 31" hi))
    (unless (exact-nonnegative-integer? value)
      (raise-argument-error struct-name "exact-nonnegative-integer?" value))
    (define width (add1 (- hi lo)))
    (unless (< value (arithmetic-shift 1 width))
      (error struct-name
             "value ~a does not fit in ~a bit(s) [~a..~a]"
             value width lo hi))
    (values name lo hi value)))

(define (constant-field-width c)
  (add1 (- (constant-field-hi c) (constant-field-lo c))))

(define (make-constant-field name lo hi value)
  (constant-field name lo hi value))

(define (encode-constant-field c)
  (arithmetic-shift (constant-field-value c)
                    (constant-field-lo c)))

(provide
 slice slice? slice-value-lo slice-value-hi slice-target-lo
 slice-width slice-target-hi
 slice-encode slice-decode slice->encoder slice->decoder

 field field? field-name field-slices field-signed? field-align
 make-field field-expectation
 field-width field-implicit-bits field-min field-max field-target-bits
 encode-field decode-field

 constant-field constant-field? constant-field-name
 constant-field-lo constant-field-hi constant-field-value
 constant-field-width encode-constant-field make-constant-field

 power-of-two? implicit-zero-bits bit-mask)
