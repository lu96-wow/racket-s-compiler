#lang racket
;;; D1/test.rkt -- 数据定义: rich 数据 -> 核心数据 item

(require rackunit
         "expand.rkt")

(define (ex x) (expand-data x))

;; ---------------------------------------------------------------------------
;; 宽度/值: 只交出"宽度 + 值"; **端序不归本层**(L7 落字节时才定)
;; ---------------------------------------------------------------------------

(check-equal? (ex '((b8 32))) '((value 1 32)))
(check-equal? (ex '((b16 258))) '((value 2 258)))
(check-equal? (ex '((b32 #x12345678))) '((value 4 #x12345678)))
(check-equal? (ex '((b64 -1))) '((value 8 -1)))

;; 值域: 有符号/无符号都收
(check-equal? (ex '((b8 -128))) '((value 1 -128)))
(check-equal? (ex '((b8 255))) '((value 1 255)))
(check-exn exn:fail? (lambda () (ex '((b8 256)))))
(check-exn exn:fail? (lambda () (ex '((b8 -129)))))
(check-exn exn:fail? (lambda () (ex '((b16 1.5)))))
(check-exn exn:fail? (lambda () (ex '((b32 "x")))))

;; ---------------------------------------------------------------------------
;; 地址值: 只留"宽度 + 链 + 加数", 值和字节序都等后面
;; ---------------------------------------------------------------------------

(check-equal? (ex '((b32 (label+ (d t) 8)))) '((value 4 (label+ (d t) 8))))
;; label- 归一成负加数; 加数一定写出来(字段固定)
(check-equal? (ex '((b32 (label- (d t) 8)))) '((value 4 (label+ (d t) -8))))
(check-equal? (ex '((b64 (label+ (d t))))) '((value 8 (label+ (d t) 0))))
(check-equal? (ex '((b64 (label- (d t))))) '((value 8 (label+ (d t) 0))))
(check-equal? (ex '((b64 (label+ (d t) 0)))) '((value 8 (label+ (d t) 0))))
;; 错误
(check-exn exn:fail? (lambda () (ex '((b64 (label+))))))              ; 没链
(check-exn exn:fail? (lambda () (ex '((b64 (label+ (d t) "x"))))))   ; 加数不是整数
(check-exn exn:fail? (lambda () (ex '((b64 (label+ (d t) 1 2))))))   ; 参数过多

;; ---------------------------------------------------------------------------
;; 字符串: 在 D1 落成 bytes(UTF-8 是定序字节, 不涉及端序)
;; ---------------------------------------------------------------------------

(check-equal? (ex '((utf-string "abc"))) '((bytes 97 98 99)))
(check-equal? (ex '((utf-string "é"))) '((bytes #xC3 #xA9)))
(check-equal? (ex '((utf-string ""))) '((bytes)))
(check-equal? (ex '((utf-stringz "abc"))) '((bytes 97 98 99 0)))
(check-equal? (ex '((utf-stringz ""))) '((bytes 0)))
(check-exn exn:fail? (lambda () (ex '((utf-string 42)))))
(check-exn exn:fail? (lambda () (ex '((utf-string "a" "b")))))

;; ---------------------------------------------------------------------------
;; 数组: 只有"与端序无关"的能压成一条 fill, 其余一个元素一条 (value …)
;; ---------------------------------------------------------------------------

;; 宽度 1: 一个元素就是一个字节 -> 压
(check-equal? (ex '((b8-array 4096 0))) '((fill 4096 0)))
(check-equal? (ex '((b8-array 4096 7))) '((fill 4096 7)))
(check-equal? (ex '((b8-array 4096 -1))) '((fill 4096 #xFF)))
;; 值全 0: 两种端序下都是全 0 -> 压
(check-equal? (ex '((b32-array 1000000 0))) '((fill 4000000 0)))
;; 宽度 > 1 且值非 0: 字节序没定, 不能合并
(check-equal? (ex '((b16-array 3 258))) '((value 2 258) (value 2 258) (value 2 258)))
;; 前 k 个给定, 剩下用最后一个
(check-equal? (ex '((b8-array 5 1 2))) '((value 1 1) (value 1 2) (fill 3 2)))
(check-equal? (ex '((b16-array 3 1 2)))
              '((value 2 1) (value 2 2) (value 2 2)))
;; 地址数组(跳转表): 每个元素一条 value
(check-equal? (ex '((b64-array 2 (label+ (f) 0))))
              '((value 8 (label+ (f) 0)) (value 8 (label+ (f) 0))))
(check-equal? (ex '((b64-array 3 (label+ (f) 0) 7)))
              '((value 8 (label+ (f) 0)) (value 8 7) (value 8 7)))
;; 空数组
(check-equal? (ex '((b8-array 0))) '((bytes)))
;; 幂等
(check-equal? (ex (ex '((b8-array 4096 0)))) '((fill 4096 0)))
(check-equal? (ex (ex '((b16-array 3 258)))) '((value 2 258) (value 2 258) (value 2 258)))

;; 错误
(check-exn exn:fail? (lambda () (ex '((b8-array)))))            ; 没给总数
(check-exn exn:fail? (lambda () (ex '((b8-array 5)))))          ; 没给初始化值
(check-exn exn:fail? (lambda () (ex '((b8-array 2 1 2 3)))))    ; 初始化值过多
(check-exn exn:fail? (lambda () (ex '((b8-array -1 0)))))       ; 总数非法
(check-exn exn:fail? (lambda () (ex '((b8-array 2 1 300)))))    ; 值越界
(check-exn exn:fail? (lambda () (ex '((b8-array 0 1)))))        ; size 0 却有值
(check-equal? (ex '((b32-array 2 1 (label+ (d t) 4))))
              '((value 4 1) (value 4 (label+ (d t) 4))))

;; ---------------------------------------------------------------------------
;; 核心形式: 透传 / 幂等
;; ---------------------------------------------------------------------------

(check-equal? (ex '((label d t) (bytes 1 2) (align 8)))
              '((label d t) (bytes 1 2) (align 8)))
(check-equal? (ex (ex '((b32 5) (utf-string "x") (label d t) (align 4))))
              (ex '((b32 5) (utf-string "x") (label d t) (align 4))))

;; 旧壳
(check-equal? (ex '(quote ((b8 1)))) '((value 1 1)))
(check-equal? (ex '(begin (b8 1))) '((value 1 1)))
(check-equal? (ex '()) '())

;; 词汇封闭: 段/放置/模块/未知形式都不是本层的词汇
(check-exn exn:fail? (lambda () (ex '((segment d data 0 1 1)))))
(check-exn exn:fail? (lambda () (ex '((segments (segment d data 0 1 1))))))
(check-exn exn:fail? (lambda () (ex '((place d (d t))))))
(check-exn exn:fail? (lambda () (ex '((module m (label d t))))))
(check-exn exn:fail? (lambda () (ex '((word 1)))))
(check-exn exn:fail? (lambda () (ex '((b8)))))
(check-exn exn:fail? (lambda () (ex '((bytes 999)))))

;; 输出词汇封闭: 只会出现 label / bytes / fill / value / align
(define (core-item? it)
  (and (pair? it) (memq (car it) '(label bytes fill value align)) #t))
(for ([it (in-list (ex '((label d t) (b8 1) (utf-string "x") (b16-array 4 2 3)
                         (b8-array 4096 0) (align 8) (bytes 3))))])
  (check-true (core-item? it)))
(check-equal? (filter (lambda (it) (not (core-item? it)))
                      (ex '((label d t) (b8 1) (b64 -1) (b32-array 9 0)
                            (utf-string "x") (align 8) (bytes 3))))
              '())

;; fill / value 也是本层的核心形式: 透传 + 幂等(形状判定归 L5, 见 L5/test.rkt)
(check-equal? (ex '((fill 5 0))) '((fill 5 0)))
(check-equal? (ex (ex '((b32-array 8 0)))) '((fill 32 0)))
(check-equal? (ex '((value 4 (label+ (d t) 0)))) '((value 4 (label+ (d t) 0))))

;; 宽度表
(check-equal? (map width-of '((b8 0) (b16 0) (b32 0) (b64 0))) '(1 2 4 8))

(displayln "D1 tests: ok")
