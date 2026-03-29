#lang racket

(require "../base.rkt")

;; 通用有符号范围检查（逻辑位 low..high）
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

;; 带对齐的有符号范围检查（align: 对齐字节数，如 2 表示 2-byte aligned）
(define (check-signed-range/aligned name value low high align)
  (check-signed-range name value low high)
  (unless (= (bitwise-and value (sub1 align)) 0)
    (error name "Value ~a is not ~a-byte aligned" value align)))

(define (make-checked-field base-proc field-name low high)
  (lambda (value)
    (check-signed-range field-name value low high)
    (base-proc value)))

(define (make-aligned-checked-field base-proc field-name low high align)
  (lambda (value)
    (check-signed-range/aligned field-name value low high align)
    (base-proc value)))

(define (imm20-check value)
  (check-signed-range 'imm20 value 0 31)
  ;;低12位必须为0
  (unless (= (bitwise-and value #xfff) 0)
    (error 'imm20 "Lower 12 bits must be zero" value))
  value)

(define imm20
  (lambda (value)
    ((make-checked-field
      (bit-range 12 31 12 31)
      'imm20
      0 31)
     (imm20-check value))))

(define rs1   (make-checked-field (bit-range 0 4 15 19)   'rs1   0 4))
(define rs2   (make-checked-field (bit-range 0 4 20 24)   'rs2   0 4))
(define rd    (make-checked-field (bit-range 0 4 7 11)    'rd    0 4))
(define imm12 (make-checked-field (bit-range 0 11 20 31)  'imm12 0 11))
(define fm    (make-checked-field (bit-range 0 3 28 31)   'fm    0 3))
(define pred  (make-checked-field (bit-range 0 3 24 27)   'pred  0 3))
(define succ  (make-checked-field (bit-range 0 3 20 23)   'succ  0 3))

(define shamtd (make-checked-field (bit-range 0 5 20 25)   'shamtd  0 5))
(define shamtw (make-checked-field (bit-range 0 4 20 24)   'shamtd  0 4))

(define simm12
  (make-checked-field (bit-range-split (bit-range 5 11 25 31)
                                       (bit-range 0 4 7 11))
                      'simm12 0 11))
(define bimm12-base
  (bit-range-split (bit-range 11 7)
                   (bit-range 1 4 8 11)
                   (bit-range 5 10 25 30)
                   (bit-range 12 31)))
(define bimm12 (make-aligned-checked-field bimm12-base 'bimm12 0 11 2))

(define jimm20-base
  (bit-range-split (bit-range 20 31)
                   (bit-range 1 10 21 30)
                   (bit-range 11 20)
                   (bit-range 12 19 12 19)))
(define jimm20 (make-aligned-checked-field jimm20-base 'jimm20 0 19 2))

(define PI #b1000) (define PO #b0100) (define PR #b0010) (define PW #b0001)
(define SI #b1000) (define SO #b0100) (define SR #b0010) (define SW #b0001)

(provide rs1 rs2 rd imm12 simm12 bimm12 imm20 jimm20 fm pred succ shamtd shamtw
         PI PO PR PW SI SO SR SW)