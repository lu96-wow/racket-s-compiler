#lang racket/base

;; ============================================================
;; RISC-V 长度（parcel）规则测试
;;
;; 用合成取位函数覆盖：16 / 32 / >=48 / 无法判定 / 低两位未固定。
;; bits 表里 #f 表示该 bit 没有被定义固定。
;; ============================================================

(require rackunit
         "../binary-build/riscv/parcel.rkt")

(define (lookup bits)
  (lambda (index)
    (and (< index (vector-length bits))
         (vector-ref bits index))))

(define (width bits)
  (parcel-length (lookup bits) "test-instruction"))

;; 16 位：bits[1:0] != 11
(check-equal? (width #(0 0)) 16)          ; quadrant 0
(check-equal? (width #(1 0)) 16)          ; quadrant 1
(check-equal? (width #(0 1)) 16)          ; quadrant 2
(check-equal? (width #(0 1 1 1 1)) 16)    ; bits[4:2] 全 1 也不影响

;; 32 位：bits[1:0] = 11 且 bits[4:2] != 111
(check-equal? (width #(1 1 0 0 0)) 32)          ; bbb = 000
(check-equal? (width #(1 1 1 0 0)) 32)          ; bbb = 100
(check-equal? (width #(1 1 1 1 0)) 32)          ; bbb = 110
(check-equal? (width #(1 1 #f #f 0)) 32)        ; bit4 固定为 0 就够
(check-equal? (width #(1 1 #f #f 0 0 0)) 32)    ; bits[6:5] 不参与判定

;; >= 48 位：bits[4:2] = 111，当前不支持，必须报错
(check-exn exn:fail? (lambda () (width #(1 1 1 1 1))))
(check-exn exn:fail? (lambda () (width #(1 1 1 1 1 0))))
(check-exn exn:fail? (lambda () (width #(1 1 1 1 1 0 0))))

;; 位不足：bit0 / bit1 必须固定
(check-exn exn:fail? (lambda () (width #(#f 1))))
(check-exn exn:fail? (lambda () (width #(1 #f))))

;; bits[4:2] 不足以区分 32 位与 >= 48 位
(check-exn exn:fail? (lambda () (width #(1 1 1 #f #f))))
(check-exn exn:fail? (lambda () (width #(1 1 #f 1 #f))))
(check-exn exn:fail? (lambda () (width #(1 1 #f #f #f))))
