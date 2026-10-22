#lang racket

(require "../../base.rkt"
         "helper.rkt")

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
  (make-signed-field/aligned bimm12-base 'bimm12 0 12 2))

;; -------- J-type --------
(define jimm20-base
  (bit-range-split (bit-range 20 31)
                   (bit-range 1 10 21 30)
                   (bit-range 11 20)
                   (bit-range 12 19 12 19)))

(define jimm20
  (make-signed-field/aligned jimm20-base 'jimm20 0 20 2))

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
