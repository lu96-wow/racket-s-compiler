#lang racket
;;; sexp-test.rkt -- 顶层共享的 s-exp 形状契约

(require rackunit
         "helpers.rkt"
         "../riscv-compiler-rebuild/sexp.rkt")

;; ---------------------------------------------------------------------------
;; form? / name? / path?
;; ---------------------------------------------------------------------------

(check-true  (form? '(a b)))
(check-true  (form? '(a)))
(check-false (form? '()))
(check-false (form? 'a))
(check-false (form? '(a . b)))          ; 非真列表

(check-true  (name? 'a))
(check-true  (name? "a"))
(check-true  (name? 42))
(check-false (name? '(a)))
(check-false (name? #t))

(check-true  (path? '(a)))
(check-true  (path? '(a b "c" 42)))
(check-false (path? '()))
(check-false (path? 'a))
(check-false (path? '(a (b))))
(check-false (path? '(a #t)))

(check-equal? (normalize-path '(a b)) '(a b))
(check-equal? (normalize-path 'a) '(a))
(check-equal? (normalize-path "a") '("a"))
(check-equal? (normalize-path 42) '(42))
(check-false (normalize-path '()))
(check-false (normalize-path '(a (b))))

;; ---------------------------------------------------------------------------
;; 地址表达式
;; ---------------------------------------------------------------------------

(check-not-false (arith-head? '(+ 1 2)))
(check-not-false (arith-head? '(- 1 2)))
(check-false (arith-head? '(* 1 2)))
(check-false (arith-head? '(a b)))

(check-true  (arith-form? '(+ 1 2)))
(check-true  (arith-form? '(- 1 2 3)))
(check-true  (arith-form? '(+ (a) (- (b) 2))))
(check-false (arith-form? '(+)))
(check-false (arith-form? '(+ 1)))
(check-false (arith-form? '(+ 1 "x")))   ; 字符串不是地址表达式

(check-true  (address-expr? 0))
(check-true  (address-expr? -8))
(check-true  (address-expr? '(a b)))
(check-true  (address-expr? '(+ (a) 8)))
(check-true  (address-expr? '(- (end) (start))))
(check-false (address-expr? 'a))         ; 裸原子不是地址表达式
(check-false (address-expr? '()))
(check-false (address-expr? '(* (a) 8)))
(check-false (address-expr? '(+ (a))))

;; 所有链都要取出来, 去重且保留首次出现顺序
(check-equal? (address-expr-chains 42) '())
(check-equal? (address-expr-chains '(a)) '((a)))
(check-equal? (address-expr-chains '(+ (a) (b) (a))) '((a) (b)))
(check-equal? (address-expr-chains '(- (end) (start))) '((end) (start)))
(check-equal? (address-expr-chains '(+ (- (end) (start)) 4))
              '((end) (start)))

;; ---------------------------------------------------------------------------
;; as-items: 宽容入口, 出口一律 plain list
;; ---------------------------------------------------------------------------

(check-equal? (as-items '((a) (b))) '((a) (b)))
(check-equal? (as-items '()) '())
(check-equal? (as-items '(a)) '((a)))                    ; 单条 item
(check-equal? (as-items '(a b)) '((a b)))                ; 单条 item 的多个原子
(check-equal? (as-items '(quote ((a) (b)))) '((a) (b)))
(check-equal? (as-items '(quote (a))) '((a)))
(check-equal? (as-items '(begin (a) (b))) '((a) (b)))
(check-equal? (as-items '(begin)) '())
(check-equal? (as-items '(begin (a))) '((a)))

;; 只有 (quote x) 且 x 是列表时才剥壳; 其它 quote 原样当一条 item
(check-equal? (as-items '(quote a)) '((quote a)))
(check-equal? (as-items '(quote (a) (b))) '((quote (a) (b))))

(finish-tests "sexp")
