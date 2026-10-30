#lang racket
;;; expand-data-test.rkt -- rich 数据 -> 核心数据 item

(require rackunit
         "helpers.rkt"
         (only-in "../riscv-compiler/expand-data/expand.rkt"
                  expand-data expand-item as-items width-form? width-of))

(define (ex x) (expand-data x))
(define (ex1 x) (expand-item x))

;; ---------------------------------------------------------------------------
;; 宽度 + 值: 只交数据, 不交端序
;; ---------------------------------------------------------------------------

(check-equal? (ex '((b8 0))) '((value 1 0)))
(check-equal? (ex '((b8 255))) '((value 1 255)))
(check-equal? (ex '((b8 -128))) '((value 1 -128)))
(check-equal? (ex '((b16 258))) '((value 2 258)))
(check-equal? (ex '((b32 #x12345678))) '((value 4 #x12345678)))
(check-equal? (ex '((b64 -1))) '((value 8 -1)))

;; 边界: 有符号下界和无符号上界都收
(check-error "b8 上界" (lambda () (ex '((b8 256)))))
(check-error "b8 下界" (lambda () (ex '((b8 -129)))))
(check-error "b16 上界" (lambda () (ex '((b16 65536)))))
(check-error "非整数" (lambda () (ex '((b32 1.5)))))
(check-error "非数值" (lambda () (ex '((b32 "x")))))

;; 输出词汇里没有 b16/b32 这类 rich 名字
(check-equal? (ex '((b16 1) (b32 2) (b64 3)))
              '((value 2 1) (value 4 2) (value 8 3)))

;; ---------------------------------------------------------------------------
;; 地址表达式: 只查形状, 不求值
;; ---------------------------------------------------------------------------

(check-equal? (ex '((b64 (d t)))) '((value 8 (d t))))
(check-equal? (ex '((b64 (+ (d t) 8)))) '((value 8 (+ (d t) 8))))
(check-equal? (ex '((b64 (- (d t) 8)))) '((value 8 (- (d t) 8))))
(check-equal? (ex '((b32 (- (d end) (d start)))))
              '((value 4 (- (d end) (d start)))))
(check-equal? (ex '((b32 (+ (- (d end) (d start)) 4))))
              '((value 4 (+ (- (d end) (d start)) 4))))
(check-equal? (ex '((b32 (+ 1 2)))) '((value 4 (+ 1 2))))

(check-error "+ 至少要两个操作数" (lambda () (ex '((b64 (+ (d t)))))))
(check-error "空 +" (lambda () (ex '((b64 (+))))))
(check-error "未知算术头" (lambda () (ex '((b64 (* (d t) 8))))))
(check-error "表达式里的坏操作数" (lambda () (ex '((b64 (+ (d t) "x"))))))

;; ---------------------------------------------------------------------------
;; 字符串 -> UTF-8 字节; 与端序无关
;; ---------------------------------------------------------------------------

(check-equal? (ex '((utf-string "abc"))) '((bytes 97 98 99)))
(check-equal? (ex '((utf-string "é"))) '((bytes #xC3 #xA9)))
(check-equal? (ex '((utf-string ""))) '((bytes)))
(check-equal? (ex '((utf-stringz "abc"))) '((bytes 97 98 99 0)))
(check-equal? (ex '((utf-stringz ""))) '((bytes 0)))
(check-error "字符串参数" (lambda () (ex '((utf-string 42)))))
(check-error "字符串个数" (lambda () (ex '((utf-string "a" "b")))))

;; ---------------------------------------------------------------------------
;; 数组: 前 k 个用给定值, 其余用最后一个; 只有与端序无关时才压成 fill
;; ---------------------------------------------------------------------------

(check-equal? (ex '((b8-array 5 0))) '((fill 5 0)))
(check-equal? (ex '((b32-array 4 0))) '((fill 16 0)))
(check-equal? (ex '((b8-array 5 1 2)))
              '((value 1 1) (value 1 2) (fill 3 2)))
(check-equal? (ex '((b16-array 3 258)))
              '((value 2 258) (value 2 258) (value 2 258)))
(check-equal? (ex '((b32-array 4 1 2)))
              '((value 4 1) (value 4 2) (value 4 2) (value 4 2)))
(check-equal? (ex '((b8-array 0))) '((bytes)))
(check-equal? (ex '((b8-array 3 (t)))) 
              '((value 1 (t)) (value 1 (t)) (value 1 (t))))

(check-error "数组大小必须是非负整数" (lambda () (ex '((b8-array -1 0)))))
(check-error "有大小就得有初值" (lambda () (ex '((b8-array 3)))))
(check-error "初值不能多于大小" (lambda () (ex '((b8-array 2 1 2 3)))))
(check-error "0 大小不能有初值" (lambda () (ex '((b8-array 0 1)))))

;; ---------------------------------------------------------------------------
;; 透传: 核心形式幂等; module 壳保留并递归
;; ---------------------------------------------------------------------------

(check-equal? (ex '((label d t))) '((label d t)))
(check-equal? (ex '((bytes 1 2 255))) '((bytes 1 2 255)))
(check-equal? (ex '((fill 3 7))) '((fill 3 7)))
(check-equal? (ex '((pad 5))) '((pad 5)))
(check-equal? (ex '((align 8))) '((align 8)))
(check-equal? (ex '((value 4 7))) '((value 4 7)))
(check-equal? (ex '((value 8 (d t)))) '((value 8 (d t))))

(check-equal? (ex '((module m
                     (provide t)
                     (require d)
                     (label d t)
                     (b16 258))))
              '((module m
                 (provide t)
                 (require d)
                 (label d t)
                 (value 2 258))))

;; 再跑一次不变
(define once
  (ex '((label d t) (b8 1) (b16 258) (utf-stringz "hi")
        (b32-array 3 1 2) (pad 4) (align 8)
        (module m (label x) (b8 9)))))
(check-equal? (ex once) once)

;; 入口接受旧壳, 出口是 plain list
(check-equal? (ex '(quote ((b8 1)))) '((value 1 1)))
(check-equal? (ex '(begin (b8 1) (b8 2)))
              '((value 1 1) (value 1 2)))

;; ---------------------------------------------------------------------------
;; 输出词汇封闭: 下游只会看到这些头
;; ---------------------------------------------------------------------------

(define (outer-heads items)
  (for/list ([it (in-list items)] #:when (pair? it)) (car it)))

(check-equal? (outer-heads
               (ex '((label d t) (bytes 1) (fill 2 0) (pad 3) (align 4)
                     (b8 1) (utf-string "x") (b8-array 2 0)
                     (module m (label x) (b8 2)))))
              '(label bytes fill pad align value bytes fill module))
(check-false (memq 'b16 (outer-heads (ex '((b16 1))))))
(check-false (memq 'utf-string (outer-heads (ex '((utf-string "x"))))))

;; ---------------------------------------------------------------------------
;; 小 API
;; ---------------------------------------------------------------------------

(check-true  (width-form? '(b16 1)))
(check-false (width-form? '(b16 1 2)))
(check-equal? (width-of '(b8 1)) 1)
(check-equal? (width-of '(b16 1)) 2)
(check-equal? (width-of '(b32 1)) 4)
(check-equal? (width-of '(b64 1)) 8)
(check-equal? (ex1 '(b8 1)) '((value 1 1)))
(check-equal? (as-items '(b8 1)) '((b8 1)))   ; 数据入口共享 as-items 的宽容规则

(finish-tests "expand-data")
