#lang racket/base

;; ============================================================
;; F-asm reference interpreter + Scheme core compiler 测试
;; ============================================================

(require rackunit
         racket/list
         racket/port
         "../fasm.rkt"
         "../fasm-interp.rkt"
         "../scheme-core.rkt")

(define (run expr)
  (run-fasm (compile-scheme expr)))

;; ------------------------------------------------------------
;; 值表示
;; ------------------------------------------------------------

(check-true (fixnum? (encode-fixnum 42)))
(check-equal? (decode-fixnum (encode-fixnum 42)) 42)
(check-equal? (decode-fixnum (encode-fixnum -7)) -7)

(check-equal? FALSE 7)
(check-equal? TRUE 15)
(check-equal? NIL 23)
(check-true (boolean-value? TRUE))
(check-true (boolean-value? FALSE))
(check-true (nil-value? NIL))
(check-false (nil-value? FALSE))

(check-equal? (decode-char (encode-char #\a)) #\a)

;; ------------------------------------------------------------
;; 手写 F-asm：字面量 / 闭包 / continuation
;; ------------------------------------------------------------

(check-equal?
 (run-fasm '(fasm
              (label main)
              (const v0 42)
              (return (v0))))
 42)

(check-equal?
 (run-fasm-raw '(fasm
                  (label main)
                  (const v0 42)
                  (return (v0))))
 (encode-fixnum 42))

;; 闭包捕获 + 调用
(check-equal?
 (run-fasm
  '(fasm
    (label main)
    (alloc-frame 1)
    (const v0 41)
    (env-set (env 0 0) v0)
    (closure v1 f 1)
    (const v2 1)
    (cont k Lafter)
    (pack argv v2)
    (call v1 argv (cont k))
    (label Lafter)
    (arg-ref v0 0)
    (pack vals v0)
    (return vals)
    (label f)
    (alloc-frame 2)
    (arg-ref v2 0)
    (env-set (env 0 0) v2)
    (env-ref v0 (env 1 0))
    (prim add v3 v2 v0)
    (pack vals v3)
    (return vals)))
 42)

;; call/cc + continuation 调用
(check-equal?
 (run-fasm
  '(fasm
    (label main)
    (alloc-frame 0)
    (cont k L1)
    (closure v1 f 1)
    (prim call/cc v1)
    (label L1)
    (arg-ref v0 0)
    (pack vals v0)
    (return vals)
    (label f)
    (alloc-frame 1)
    (arg-ref v2 0)
    (env-set (env 0 0) v2)
    (env-ref v0 (env 0 0))
    (const v1 41)
    (pack argv v1)
    (tailcall v0 argv)))
 41)

;; 编译器输出必须是纯 value-vector 形式：不能出现 a0..a7。
(let ()
  (define fasm
    (compile-scheme
     '(letrec ((fact (lambda (n)
                       (if (= n 0)
                           1
                           (* n (fact (- n 1)))))))
        (fact 5))))
  (define (real-register-symbol? x)
    (and (symbol? x)
         (regexp-match? #rx"^a[0-7]$" (symbol->string x))))
  (define (contains-real-register? x)
    (cond
      [(real-register-symbol? x) #t]
      [(list? x) (ormap contains-real-register? x)]
      [else #f]))
  (check-false (contains-real-register? fasm)))

;; ------------------------------------------------------------
;; Scheme core：基础
;; ------------------------------------------------------------

(check-equal? (run 42) 42)
(check-equal? (run '(+ 1 2)) 3)
(check-equal? (run '(- 10 3)) 7)
(check-equal? (run '(* 6 7)) 42)
(check-equal? (run '(/ 84 2)) 42)
(check-equal? (run '(if #t 1 2)) 1)
(check-equal? (run '(if #f 1 2)) 2)
(check-equal? (run '(if #f 1)) '())

(check-equal? (run '(let ((x 2)) (+ x 40))) 42)
(check-equal? (run '(let ((x 1) (y 2)) (+ x y))) 3)
(check-equal? (run '(begin 1 2 42)) 42)

(check-equal? (run '((lambda (x) (+ x 1)) 41)) 42)
(check-equal? (run '((lambda () 42))) 42)
(check-equal? (run '(((lambda (x) (lambda (y) (+ x y))) 2) 40)) 42)

;; ------------------------------------------------------------
;; quote / list / symbol
;; ------------------------------------------------------------

(check-equal? (run '(quote (1 2 3))) '(1 2 3))
(check-equal? (run '(car (quote (1 2 3)))) 1)
(check-equal? (run '(cdr (quote (1 2 3)))) '(2 3))
(check-equal? (run '(car (cdr (quote (1 2 3))))) 2)
(check-equal? (run '(null? (quote ()))) #t)
(check-equal? (run '(pair? (quote (1)))) #t)
(check-equal? (run '(cons 1 2)) '(1 . 2))

(check-equal? (run '(eq? (quote a) (quote a))) #t)
(check-equal? (run '(eq? (quote a) (quote b))) #f)
(check-equal? (run '(eq? 1 1)) #t)

;; ------------------------------------------------------------
;; 递归 / 非尾调用 / 尾调用
;; ------------------------------------------------------------

(check-equal?
 (run '(letrec ((fact (lambda (n)
                        (if (= n 0)
                            1
                            (* n (fact (- n 1)))))))
        (fact 5)))
 120)

(check-equal?
 (run '(letrec ((fact (lambda (n)
                        (if (= n 0)
                            1
                            (* n (fact (- n 1)))))))
        (fact 6)))
 720)

;; 非尾递归：continuation 链在 heap 上，不走 host 栈。
(check-equal?
 (run '(letrec ((sum (lambda (n)
                       (if (= n 0)
                           0
                           (+ n (sum (- n 1)))))))
        (sum 1000)))
 500500)

;; 尾递归：不分配 continuation。
(check-equal?
 (run '(letrec ((loop (lambda (n acc)
                        (if (= n 0)
                            acc
                            (loop (- n 1) (+ acc n))))))
        (loop 10000 0)))
 50005000)

;; 互递归
(check-equal?
 (run '(letrec ((even? (lambda (n)
                         (if (= n 0) #t (odd? (- n 1)))))
                (odd? (lambda (n)
                        (if (= n 0) #f (even? (- n 1))))))
        (even? 10)))
 #t)

;; ------------------------------------------------------------
;; set! / box / 闭包状态
;; ------------------------------------------------------------

(check-equal?
 (run '(let ((x 1)) (begin (set! x 2) x)))
 2)

(check-equal?
 (run '(let ((make-counter
              (lambda ()
                (let ((n 0))
                  (lambda ()
                    (begin (set! n (+ n 1)) n))))))
        (let ((c (make-counter)))
          (begin (c) (c) (c)))))
 3)

(check-equal?
 (run '(let ((b (box 1)))
        (begin (set-box! b 42) (unbox b))))
 42)

;; ------------------------------------------------------------
;; call/cc
;; ------------------------------------------------------------

(check-equal?
 (run '(+ 1 (call/cc (lambda (k) (k 41)))))
 42)

;; multi-shot：同一个 continuation 调用两次
(check-equal?
 (run '(let ((k #f) (n 0))
        (begin
          (call/cc (lambda (c) (set! k c)))
          (if (< n 2)
              (begin (set! n (+ n 1)) (k n))
              n))))
 2)

;; ------------------------------------------------------------
;; display
;; ------------------------------------------------------------

(check-equal?
 (with-output-to-string
   (lambda ()
     (check-equal? (run '(begin (display "hello") 42)) 42)))
 "hello")

(check-equal?
 (with-output-to-string
   (lambda ()
     (check-equal? (run '(begin (display (quote (1 2 3))) 42)) 42)))
 "(1 2 3)")
