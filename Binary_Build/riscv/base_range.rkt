#lang racket

(require "../base.rkt")

;; 基础检查函数

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

;; bitfield 类型（用于寄存器、lui、opcode字段等）
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

;; 字段定义

;; -------- register --------
(define rs1 (make-bitfield-field (bit-range 0 4 15 19) 'rs1 0 4))
(define rs2 (make-bitfield-field (bit-range 0 4 20 24) 'rs2 0 4))
(define rd  (make-bitfield-field (bit-range 0 4 7 11)  'rd  0 4))

;; -------- U-type (LUI / AUIPC) --------
;; value 是完整 32-bit 地址（低12位必须0）
(define (imm20 value)
  (unless (and (integer? value) (exact? value))
    (error 'imm20 "Value must be integer" value))

  ;; 允许完整 32-bit
  (when (or (< value 0) (> value #xFFFFFFFF))
    (error 'imm20 "Value out of 32-bit range" value))

  ;; 低12位必须为0
  (unless (= (bitwise-and value #xfff) 0)
    (error 'imm20 "Lower 12 bits must be zero" value))

  ;; 只取 [31:12]
  ((bit-range 12 31 12 31) value))

;; -------- I-type --------
(define imm12
  (make-signed-field (bit-range 0 11 20 31) 'imm12 0 11))

;; -------- S-type --------
(define simm12
  (make-signed-field
   (bit-range-split (bit-range 5 11 25 31)
                    (bit-range 0 4 7 11))
   'simm12
   0 11))

;; -------- B-type --------
(define bimm12-base
  (bit-range-split (bit-range 11 7)
                   (bit-range 1 4 8 11)
                   (bit-range 5 10 25 30)
                   (bit-range 12 31)))

(define bimm12
  (make-signed-field/aligned bimm12-base 'bimm12 0 11 2))

;; -------- J-type --------
(define jimm20-base
  (bit-range-split (bit-range 20 31)
                   (bit-range 1 10 21 30)
                   (bit-range 11 20)
                   (bit-range 12 19 12 19)))

(define jimm20
  (make-signed-field/aligned jimm20-base 'jimm20 0 19 2))

;; -------- 其它字段 --------
(define fm    (make-bitfield-field (bit-range 0 3 28 31) 'fm    0 3))
(define pred  (make-bitfield-field (bit-range 0 3 24 27) 'pred  0 3))
(define succ  (make-bitfield-field (bit-range 0 3 20 23) 'succ  0 3))

(define shamtd (make-bitfield-field (bit-range 0 5 20 25) 'shamtd 0 5))
(define shamtw (make-bitfield-field (bit-range 0 4 20 24) 'shamtw 0 4))

;; -------- fence flags --------
(define PI #b1000) (define PO #b0100) (define PR #b0010) (define PW #b0001)
(define SI #b1000) (define SO #b0100) (define SR #b0010) (define SW #b0001)

(provide
 rs1 rs2 rd
 imm12 simm12 bimm12 jimm20 imm20
 fm pred succ shamtd shamtw
 PI PO PR PW SI SO SR SW)