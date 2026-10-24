#lang racket/base

(require rackunit
         racket/list
         racket/set
         "../generated/lib/riscv/instruction_info/struct.rkt"
         "../generated/lib/riscv/instruction_info/query.rkt"
         "../generated/lib/riscv/instruction_info/lookup.rkt"
         "../generated/lib/instruction_paths.rkt"
         "field-ranges.rkt")

;; ============================================================
;; 每条 generated instruction 的逐操作数范围测试
;;
;; 对每条指令、每个操作数：
;;   - 合法值：0 / +1 / -1 / min / max（在范围内）
;;   - 非法值：min-1 / max+1 / 未对齐值
;; 合法值必须成功，非法值必须抛错。
;; ============================================================

(define (range-for name)
  (hash-ref field-ranges (string->symbol name) #f))

(define (valid-values min max align)
  (define candidates
    (for/list ([v (in-list (list 0 1 -1 min max))]
               #:when (and (>= v min)
                           (<= v max)
                           (zero? (modulo v align))))
      v))
  (remove-duplicates candidates))

(define (invalid-values min max align)
  (define misaligned
    (if (> align 1)
        (list (if (< (add1 min) max) (add1 min) (sub1 max)))
        '()))
  (remove-duplicates
   (append (list (sub1 min) (add1 max)) misaligned)))

(define (safe-value min max align)
  (if (and (>= 0 min) (<= 0 max) (zero? (modulo 0 align)))
      0
      min))

(define (rebuilt-proc info)
  (dynamic-require
   (list 'file
         (rebuilt-instruction-path (instruction-info-extension info)))
   (instruction-info-name info)))

(define checked-values 0)
(define checked-instructions 0)
(define missing-ranges (mutable-set))

(define (check-instruction info)
  (define names (instruction-info-operands info))
  (define ranges
    (for/list ([name (in-list names)])
      (define r (range-for name))
      (unless r (set-add! missing-ranges name))
      r))

  (when (andmap values ranges)
    (define proc (rebuilt-proc info))
    (define base
      (for/list ([r (in-list ranges)])
        (safe-value (first r) (second r) (third r))))

    ;; 全 safe 参数至少成功一次
    (check-not-exn (lambda () (apply proc base)))
    (set! checked-instructions (add1 checked-instructions))

    (for ([name (in-list names)]
          [r (in-list ranges)]
          [idx (in-naturals)])
      (define min (first r))
      (define max (second r))
      (define align (third r))

      (for ([v (in-list (valid-values min max align))])
        (define args (list-set base idx v))
        (check-not-exn
         (lambda () (apply proc args))
         (format "valid value failed: ~a::~a ~a=~a"
                 (instruction-info-extension info)
                 (instruction-info-name info)
                 name v))
        (set! checked-values (add1 checked-values)))

      (for ([v (in-list (invalid-values min max align))])
        (define args (list-set base idx v))
        (check-exn
         exn:fail?
         (lambda () (apply proc args))
         (format "expected error: ~a::~a ~a=~a"
                 (instruction-info-extension info)
                 (instruction-info-name info)
                 name v))
        (set! checked-values (add1 checked-values))))))

;; 不遍历总表：逐个扩展查它自己的表
(for ([ext (in-list (instruction-info-extensions))])
  (for ([info (in-list (extension-instruction-info ext))])
    (check-instruction info)))

(printf "instruction range test:\n  instructions: ~a\n  checked values: ~a\n"
        checked-instructions checked-values)
(when (positive? (set-count missing-ranges))
  (printf "  missing ranges: ~a\n" (sort (map symbol->string (set->list missing-ranges)) string<?)))

(check-true (> checked-instructions 800))
(check-true (zero? (set-count missing-ranges)))
(check-true (> checked-values 10000))
