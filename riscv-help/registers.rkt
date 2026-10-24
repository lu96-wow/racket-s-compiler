#lang racket/base

;; ============================================================
;; 寄存器编号辅助
;;
;; 这一层只做符号到编号的解析，不做寄存器分配。
;; 压缩分支等指令需要判断寄存器是否落在 x8..x15。
;; ============================================================

(require racket/string)

(define abi-register-table
  (hash 'zero 0
        'ra 1
        'sp 2
        'gp 3
        'tp 4
        't0 5 't1 6 't2 7
        's0 8 'fp 8 's1 9
        'a0 10 'a1 11 'a2 12 'a3 13
        'a4 14 'a5 15 'a6 16 'a7 17
        's2 18 's3 19 's4 20 's5 21
        's6 22 's7 23 's8 24 's9 25
        's10 26 's11 27
        't3 28 't4 29 't5 30 't6 31))

(define (raw-register-number reg)
  (cond
    [(exact-integer? reg) reg]
    [(hash-ref abi-register-table reg #f)]
    [(and (symbol? reg)
          (let* ([s (symbol->string reg)]
                 [n (and (string-prefix? s "x")
                         (string->number (substring s 1)))])
            n))]
    [else #f]))

(define (register-number reg)
  (define n (raw-register-number reg))
  (and n (<= 0 n 31) n))

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

(define (compressed-register? reg)
  (define n (register-number reg))
  (and n (<= 8 n 15)))

(define (nonzero-register? reg)
  (define n (register-number reg))
  (and n (not (zero? n))))

(provide register-number
         register?
         zero-register?
         same-register?
         compressed-register?
         nonzero-register?)
