#lang racket/base

;; ============================================================
;; RISC-V 寄存器表
;;
;; 所有 x0..x31 和 ABI 别名都只在这个文件维护。
;;   (list x-name '(alias ...) number)
;; ============================================================

(require racket/list
         racket/match)

(define register-info
  (list
   (list 'x0  '(zero)      0)
   (list 'x1  '(ra)        1)
   (list 'x2  '(sp)        2)
   (list 'x3  '(gp)        3)
   (list 'x4  '(tp)        4)
   (list 'x5  '(t0)        5)
   (list 'x6  '(t1)        6)
   (list 'x7  '(t2)        7)
   (list 'x8  '(s0 fp)     8)
   (list 'x9  '(s1)        9)
   (list 'x10 '(a0)       10)
   (list 'x11 '(a1)       11)
   (list 'x12 '(a2)       12)
   (list 'x13 '(a3)       13)
   (list 'x14 '(a4)       14)
   (list 'x15 '(a5)       15)
   (list 'x16 '(a6)       16)
   (list 'x17 '(a7)       17)
   (list 'x18 '(s2)       18)
   (list 'x19 '(s3)       19)
   (list 'x20 '(s4)       20)
   (list 'x21 '(s5)       21)
   (list 'x22 '(s6)       22)
   (list 'x23 '(s7)       23)
   (list 'x24 '(s8)       24)
   (list 'x25 '(s9)       25)
   (list 'x26 '(s10)      26)
   (list 'x27 '(s11)      27)
   (list 'x28 '(t3)       28)
   (list 'x29 '(t4)       29)
   (list 'x30 '(t5)       30)
   (list 'x31 '(t6)       31)))

(define name->number
  (for/fold ([table (hash)]) ([entry (in-list register-info)])
    (match-define (list x-name aliases number) entry)
    (for/fold ([table table])
              ([name (in-list (cons x-name aliases))])
      (hash-set table name number))))

(define (register-number reg)
  (cond
    [(exact-integer? reg)
     (and (<= 0 reg 31) reg)]
    [(hash-ref name->number reg #f)]
    [else #f]))

(define (register? reg)
  (and (register-number reg) #t))

(define (zero-register? reg)
  (define n (register-number reg))
  (and n (zero? n)))

(define (same-register? a b)
  (let ([na (register-number a)]
        [nb (register-number b)])
    (cond
      [(and na nb) (= na nb)]
      [else (eq? a b)])))

;; RISC-V 的 rd' / rs1' / rs2' 压缩字段只能编码 x8..x15。
(define (compressed-prime-register? reg)
  (define n (register-number reg))
  (and n (<= 8 n 15)))

;; C.BEQZ / C.BNEZ 使用 rs1'，因此也限制在 x8..x15。
(define (compressed-branch-register? reg)
  (compressed-prime-register? reg))

(define (nonzero-register? reg)
  (define n (register-number reg))
  (and n (not (zero? n))))

(provide register-number
         register?
         zero-register?
         same-register?
         compressed-prime-register?
         compressed-branch-register?
         nonzero-register?)
