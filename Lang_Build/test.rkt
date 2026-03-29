#lang racket

(require "namespace.rkt")

(define (test msg result expected)
  (printf "~a: ~a~n" msg (if (equal? result expected) "OK" (format "FAIL! got ~v, want ~v" result expected))))

;; 1. 基本定义与查找
(let ([ns (make-namespace)])
  (namespace-define ns 'x 10)
  (test "define/find" (namespace-find ns 'x) 10)
  (test "find missing" (namespace-find ns 'y 'not-found) 'not-found))

;; 2. 作用域嵌套
(let ([ns (make-namespace)])
  (namespace-define ns 'a 1)
  (namespace-push ns)
  (namespace-define ns 'b 2)
  (test "inner scope sees outer" (namespace-find ns 'a) 1)
  (test "inner has b" (namespace-find ns 'b) 2)
  (namespace-pop ns)
  (test "after pop, b gone" (namespace-find ns 'b #f) #f))

;; 3. provide / require
(let ([lib (make-namespace)])
  (namespace-define lib 'pi 3.14)
  (let-values ([(mod-ns missing) (namespace-provide lib '(pi tau) 'math)])
    (test "provide missing" missing '(tau))
    (let ([user (make-namespace)])
      (namespace-require user mod-ns)
      (test "require pi" (namespace-find user 'pi) 3.14))))

;; 4. 后 require 的优先
(let ([ns (make-namespace)])
  (let ([m1 (make-namespace)])
    (namespace-define m1 'x 'first)
    (let-values ([(p1 _) (namespace-provide m1 '(x) 'm1)])
      (namespace-require ns p1)))
  (let ([m2 (make-namespace)])
    (namespace-define m2 'x 'second)
    (let-values ([(p2 _) (namespace-provide m2 '(x) 'm2)])
      (namespace-require ns p2)))
  (test "later require wins" (namespace-find ns 'x) 'second))

;; 5. unrequire
(let ([ns (make-namespace)]
      [m (make-namespace)])
  (namespace-define m 'z 999)
  (let-values ([(mod _) (namespace-provide m '(z) 'Z)])
    (namespace-require ns mod)
    (test "before unrequire" (namespace-find ns 'z) 999)
    (namespace-unrequire ns 'Z)
    (test "after unrequire" (namespace-find ns 'z #f) #f)))

;; 6. redefine
(let ([ns (make-namespace)])
  (namespace-define ns 'old 42)
  (test "redefine success" (namespace-redefine ns 'old 'new) 42)
  (test "new exists" (namespace-find ns 'new) 42)
  (test "redefine missing" (namespace-redefine ns 'nope 'x 'dflt) 'dflt))

(printf "=== 所有测试完成 ===\n")