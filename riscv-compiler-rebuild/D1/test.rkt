#lang racket
;;; D1/test.rkt -- 数据定义: rich 数据 -> 核心数据 item

(require rackunit
         "expand.rkt")

(define (ex x) (expand-data x))

;; ---------------------------------------------------------------------------
;; 宽度/值: 本层直接落成定序字节(小端), 下游不再需要宽度
;; ---------------------------------------------------------------------------

(check-equal? (ex '((b8 32))) '((bytes 32)))
(check-equal? (ex '((b16 258))) '((bytes 2 1)))
(check-equal? (ex '((b32 #x12345678))) '((bytes #x78 #x56 #x34 #x12)))
(check-equal? (ex '((b64 -1))) '((bytes #xFF #xFF #xFF #xFF #xFF #xFF #xFF #xFF)))

;; 值域: 有符号/无符号都收
(check-equal? (ex '((b8 -128))) '((bytes #x80)))
(check-equal? (ex '((b8 255))) '((bytes #xFF)))
(check-exn exn:fail? (lambda () (ex '((b8 256)))))
(check-exn exn:fail? (lambda () (ex '((b8 -129)))))
(check-exn exn:fail? (lambda () (ex '((b16 1.5)))))
(check-exn exn:fail? (lambda () (ex '((b32 "x")))))

;; 地址表达式暂不支持
(check-exn exn:fail? (lambda () (ex '((b32 (label+ (d t) 8))))))
(check-exn exn:fail? (lambda () (ex '((b32 (label- (d t) 8))))))

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
;; 数组: (bN-array 总数 v...), 最后一个值铺满剩余; 同字节压成 fill
;; ---------------------------------------------------------------------------

;; 4096 个 0 仍然是一条 item
(check-equal? (ex '((b8-array 4096 0))) '((fill 4096 0)))
;; 前 k 个给定, 剩下用最后一个 -> 不是同一个字节, 展开
(check-equal? (ex '((b8-array 5 1 2))) '((bytes 1 2 2 2 2)))
(check-equal? (ex '((b32-array 3 7 -1)))
              '((bytes 7 0 0 0 #xFF #xFF #xFF #xFF #xFF #xFF #xFF #xFF)))
;; 正好铺满
(check-equal? (ex '((b8-array 3 1 2 3))) '((bytes 1 2 3)))
;; 空数组
(check-equal? (ex '((b8-array 0))) '((bytes)))
;; 幂等
(check-equal? (ex (ex '((b8-array 4096 0)))) '((fill 4096 0)))

;; 错误
(check-exn exn:fail? (lambda () (ex '((b8-array)))))            ; 没给总数
(check-exn exn:fail? (lambda () (ex '((b8-array 5)))))          ; 没给初始化值
(check-exn exn:fail? (lambda () (ex '((b8-array 2 1 2 3)))))    ; 初始化值过多
(check-exn exn:fail? (lambda () (ex '((b8-array -1 0)))))       ; 总数非法
(check-exn exn:fail? (lambda () (ex '((b8-array 2 1 300)))))    ; 值越界
(check-exn exn:fail? (lambda () (ex '((b8-array 0 1)))))        ; size 0 却有值
(check-exn exn:fail? (lambda () (ex '((b32-array 2 1 (label+ (d t) 4))))))

;; ---------------------------------------------------------------------------
;; 核心形式: 透传 / 幂等
;; ---------------------------------------------------------------------------

(check-equal? (ex '((label d t) (bytes 1 2) (align 8)))
              '((label d t) (bytes 1 2) (align 8)))
(check-equal? (ex (ex '((b32 5) (utf-string "x") (label d t) (align 4))))
              (ex '((b32 5) (utf-string "x") (label d t) (align 4))))

;; 旧壳
(check-equal? (ex '(quote ((b8 1)))) '((bytes 1)))
(check-equal? (ex '(begin (b8 1))) '((bytes 1)))
(check-equal? (ex '()) '())

;; 词汇封闭: 段/放置/模块/未知形式都不是本层的词汇
(check-exn exn:fail? (lambda () (ex '((segment d data 0 1 1)))))
(check-exn exn:fail? (lambda () (ex '((segments (segment d data 0 1 1))))))
(check-exn exn:fail? (lambda () (ex '((place d (d t))))))
(check-exn exn:fail? (lambda () (ex '((module m (label d t))))))
(check-exn exn:fail? (lambda () (ex '((word 1)))))
(check-exn exn:fail? (lambda () (ex '((b8)))))
(check-exn exn:fail? (lambda () (ex '((bytes 999)))))

;; 输出词汇封闭: 只会出现 label / bytes / fill / align
(define (core-item? it)
  (and (pair? it) (memq (car it) '(label bytes fill align)) #t))
(for ([it (in-list (ex '((label d t) (b8 1) (utf-string "x") (b16-array 4 2 3)
                         (b8-array 4096 0) (align 8) (bytes 3))))])
  (check-true (core-item? it)))
(check-equal? (filter (lambda (it) (not (core-item? it)))
                      (ex '((label d t) (b8 1) (b64 -1) (b32-array 9 0)
                            (utf-string "x") (align 8) (bytes 3))))
              '())

;; fill 也是本层的核心形式: 透传 + 幂等(形状判定归 L5, 见 L5/test.rkt)
(check-equal? (ex '((fill 5 0))) '((fill 5 0)))
(check-equal? (ex (ex '((b32-array 8 0)))) '((fill 32 0)))

;; 宽度表
(check-equal? (map width-of '((b8 0) (b16 0) (b32 0) (b64 0))) '(1 2 4 8))

(displayln "D1 tests: ok")
