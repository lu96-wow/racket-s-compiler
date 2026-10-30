#lang racket/base

;; ============================================================
;; RISC-V 指令长度（parcel）规则
;;
;; 规范里指令长度以 16 位 parcel 为单位，由第一个 parcel 的低位判定：
;;
;;   bits[1:0] != 11                   -> 16 位
;;   bits[1:0] == 11, bits[4:2] != 111 -> 32 位
;;   bits[1:0] == 11, bits[4:2] == 111 -> 48 位或更长
;;
;; 本模块只实现这条规则本身：输入一个取位函数，位未固定时返回 #f。
;; 不依赖 instruction-def / fixed-field / 编码器，便于单独维护和测试。
;;
;; 当前编码器（bit.rkt 的 check-target-index）只支持 <= 32 位，
;; 因此 >= 48 位一律报错，不做猜测。
;; ============================================================

(provide parcel-length)

;; bit  : exact-nonnegative-integer? -> (or/c 0 1 #f)
;; name : 指令名，仅用于报错
(define (parcel-length bit name)
  (define b0 (require-bit bit 0 name))
  (define b1 (require-bit bit 1 name))
  (cond
    ;; bits[1:0] = 11 以外都是 16 位（RVC 的四个 quadrant）
    [(not (and (= b0 1) (= b1 1))) 16]
    [else
     ;; bits[4:2] = 111 才可能是 48 位或更长；
     ;; 只要其中一位固定为 0，就一定是 32 位
     (define b2 (bit 2))
     (define b3 (bit 3))
     (define b4 (bit 4))
     (define fixed (filter (lambda (v) (not (eq? v #f)))
                           (list b2 b3 b4)))
     (cond
       [(member 0 fixed) 32]
       [(= 3 (length fixed))
        (error 'parcel-length
               "instruction ~a: bits[4:2]=111 means 48-bit or longer, which is not supported"
               name)]
       [else
        (error 'parcel-length
               "instruction ~a: cannot determine width because bits[2..4] are not fixed enough (~a ~a ~a)"
               name b2 b3 b4)])]))

(define (require-bit bit index name)
  (define value (bit index))
  (unless value
    (error 'parcel-length
           "instruction ~a: bit ~a is not fixed by the definition"
           name index))
  value)
