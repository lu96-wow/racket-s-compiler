#lang racket
;;; amd64-help/ranges.rkt
;;;
;;; 编码/布局常用的范围判断。只放纯整数谓词，不含层策略。

(provide fits-s8?
         fits-s16?
         fits-s32?
         fits-u8?
         fits-u32?
         fits-rel8?
         fits-rel32?
         fits-disp32?
         fits-width?)

(define (fits-s8? n) (<= -128 n 127))
(define (fits-s16? n) (<= (- (expt 2 15)) n (sub1 (expt 2 15))))
(define (fits-s32? n) (<= (- (expt 2 31)) n (sub1 (expt 2 31))))
(define (fits-u8? n) (<= 0 n 255))
(define (fits-u32? n) (<= 0 n (sub1 (expt 2 32))))

;; x86 branch 的 rel8 / rel32 都是有符号偏移。
(define fits-rel8? fits-s8?)
(define fits-rel32? fits-s32?)

;; disp32 在 ModR/M 里按 32 位补码落字节；允许完整无符号上界。
(define (fits-disp32? n) (<= (- (expt 2 31)) n (sub1 (expt 2 32))))

;; 有符号或无符号值能放进 width 个字节即可，供 bind-labels 的 value 检查使用。
(define (fits-width? n width)
  (define bits (* 8 width))
  (<= (- (expt 2 (sub1 bits))) n (sub1 (expt 2 bits))))
