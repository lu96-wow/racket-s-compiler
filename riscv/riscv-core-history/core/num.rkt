#lang racket
;;; core/num.rkt -- 跨层共用的整数小工具。
;;;
;;; 只放事实（对齐 / 2 的幂），不放策略。frame、call-plan、data 以前各抄一份，
;;; 抄本之间已经有细微差别（有的校验 power-of-two，有的不校验）。
;;;
;;; 约定：**校验属于边界**（item/data 的 validator），这里只做算术。
;;; 需要校验的调用点自己校验，不要再包一层同名函数。

(provide align-up
         power-of-two?)

(define (power-of-two? n)
  (and (exact-positive-integer? n)
       (zero? (bitwise-and n (sub1 n)))))

(define (align-up n alignment)
  (* (quotient (+ n (sub1 alignment)) alignment) alignment))
