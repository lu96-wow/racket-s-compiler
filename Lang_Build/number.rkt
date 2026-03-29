#lang racket

(require racket/bytes)

(define (parse-byte-number bs)
  (define str (bytes->string/utf-8 bs))

  ;; 处理负号：必须在最前面，且后面还有内容
  (define negative? #f)
  (define core-str str)
  (when (and (> (string-length str) 0)
             (char=? (string-ref str 0) #\-))
    (set! negative? #t)
    (set! core-str (substring str 1)))

  ;; core-str 不能为空
  (if (string=? core-str "")
      #f
      (cond
        ;; 带进制格式：#base#digits
        [(regexp-match #rx"^#([2-9]|1[0-9]|2[0-9]|3[0-6])#([0-9A-Za-z]+)$" core-str)
         => (lambda (m)
              (define base (string->number (cadr m)))
              (define digits (caddr m))
              (with-handlers ([exn:fail? (λ (_) #f)])
                (let ([val (string->number digits base)])
                  (if negative? (- val) val))))]

        ;; 纯十进制（只允许数字，不允许前导非零限制，允许 "0"）
        [(regexp-match #rx"^[0-9]+$" core-str)
         (let ([val (string->number core-str 10)])
           (if negative? (- val) val))]

        ;; 非法
        [else #f])))
;;支持 12 -12 #进制#数字 -#进制#数字;;

;; 有符号补码最小位宽（补码能正确表示该整数，包括负数）
(define (min-signed-bits n)
  (let loop ([k 1])
    (define half (expt 2 (sub1 k)))
    (if (and (>= n (- half)) (<= n (sub1 half)))
        k
        (loop (add1 k)))))

;; 无符号数值最小位宽（仅看绝对值）
(define (min-unsigned-bits n)
  (if (zero? n) 1 (integer-length (abs n))))

;; 检查是否为 2 的正整数次幂
(define (power-of-two? n)
  (and (exact-positive-integer? n)
       (= (bitwise-and n (sub1 n)) 0)))

;; 向下对齐（floor）：返回 ≤ x 的最大 align 的倍数
;; 要求：x 是非负整数，align 是 2 的正整数次幂
(define (align-down x align)
  (unless (power-of-two? align)
    (error 'align-down "alignment must be a power of two, got: ~a" align))
  (bitwise-and x (bitwise-not (sub1 align))))


;; 向上对齐（ceil）：返回 ≥ x 的最小 align 的倍数
;; 要求：x 是非负整数，align 是 2 的正整数次幂
(define (align-up x align)
  (unless (power-of-two? align)
    (error 'align-up "alignment must be a power of two, got: ~a" align))
  (if (= x 0)
      0
      (bitwise-and (+ x (sub1 align)) (bitwise-not (sub1 align)))))

(define (low12-signed n)
  (let ([v (bitwise-and n #xFFF)])
    (if (>= v #x800)
        (- v #x1000)  ; sign-extend: e.g., 0xFFF -> -1
        v)))

;; 判断低 12 位是否全 0
(define (low12-zero? n)
  (= (bitwise-and n #xFFF) 0))

(require "help.rkt")
(define (parse-symbol-number sym)
  (parse-byte-number (symbol->bytes sym)))

(provide
 parse-byte-number
 parse-symbol-number
 min-signed-bits
 min-unsigned-bits
 align-down
 align-up
 low12-signed
 low12-zero?)