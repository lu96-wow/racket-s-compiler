#lang racket

;; 范围检查与字段构造器 — 所有 range 模块共享的基础设施
(require "../../base.rkt")

;; 有符号数范围检查（用于 offset / addi 等）
(define (check-signed-range name value low high)
  (unless (and (integer? value) (exact? value))
    (error name "Value must be an exact integer" value))
  (let* ([width (+ (- high low) 1)]
         [min-val (- (arithmetic-shift 1 (sub1 width)))]
         [max-val (sub1 (arithmetic-shift 1 (sub1 width)))])
    (when (< value min-val)
      (error name "Value ~a below signed ~a-bit min (~a)" value width min-val))
    (when (> value max-val)
      (error name "Value ~a above signed ~a-bit max (~a)" value width max-val))))

;; bitfield 检查（核心：只允许指定 bit 范围内为非0）
(define (check-bit-range name value low high)
  (unless (and (integer? value) (exact? value))
    (error name "Value must be an exact integer" value))

  (define width (+ (- high low) 1))
  (define mask (sub1 (arithmetic-shift 1 width)))
  (define allowed-mask (arithmetic-shift mask low))

  ;; 检查是否有越界 bit
  (when (not (= (bitwise-and value (bitwise-not allowed-mask)) 0))
    (error name
           (format "Value ~a has bits outside range [~a..~a]" value low high)))

  value)

;; 对齐 + bitfield
(define (check-bit-range/aligned name value low high align)
  (check-bit-range name value low high)
  (unless (= (bitwise-and value (sub1 align)) 0)
    (error name "Value ~a is not ~a-byte aligned" value align))
  value)

;; field 构造器

;; bitfield 类型（用于寄存器、1-bit 标志位等）
(define (make-bitfield-field base-proc field-name low high)
  (lambda (value)
    (check-bit-range field-name value low high)
    (base-proc value)))

;; signed 类型（用于 offset / imm）
(define (make-signed-field base-proc field-name low high)
  (lambda (value)
    (check-signed-range field-name value low high)
    (base-proc value)))

;; signed + aligned（branch / jump）
(define (make-signed-field/aligned base-proc field-name low high align)
  (lambda (value)
    (check-signed-range field-name value low high)
    (unless (= (bitwise-and value (sub1 align)) 0)
      (error field-name "Value ~a is not ~a-byte aligned" value align))
    (base-proc value)))

(provide
 check-signed-range
 check-bit-range
 check-bit-range/aligned
 make-bitfield-field
 make-signed-field
 make-signed-field/aligned)
