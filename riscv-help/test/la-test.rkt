#lang racket/base

;; ============================================================
;; la：基础展开
;; ============================================================

(require rackunit
         "../compose.rkt")

;; ------------------------------------------------------------
;; 已知 PC-relative delta
;; ------------------------------------------------------------

(check-equal? (la-pcrel 'a0 #:delta 8)
              '((auipc a0 0) (addi a0 a0 8)))
(check-equal? (la-pcrel 'a0 #:delta 4096)
              '((auipc a0 1) (addi a0 a0 0)))
(check-equal? (la-pcrel 'a0 #:delta -8)
              '((auipc a0 0) (addi a0 a0 -8)))

(check-exn exn:fail?
           (lambda () (la-pcrel 'a0 #:delta #x100000000 #:word-size 'rv32)))
(check-exn exn:fail?
           (lambda () (la-pcrel 'a0 #:delta #x100000000 #:word-size 'rv64)))
(check-exn exn:fail?
           (lambda () (la-pcrel 'a0 #:delta 8 #:word-size 'bad)))

;; 未提供 delta 时仍然是原来的占位形式。
(check-equal? (la-pcrel 'a0)
              '((auipc a0 0) (addi a0 a0 0)))

;; ------------------------------------------------------------
;; 绝对地址 / gp / frame
;; ------------------------------------------------------------

(check-equal? (la-abs 'a0 5)
              '((addi a0 x0 5)))
(check-equal? (la-gp 'a0 16)
              '((addi a0 gp 16)))
(check-equal? (la-frame 'a0 'sp 16)
              '((addi a0 sp 16)))

(check-exn exn:fail?
           (lambda () (la-gp 'a0 4096)))

;; ------------------------------------------------------------
;; expand-la
;; ------------------------------------------------------------

(check-equal? (expand-la 'a0 8 #:mode 'pcrel)
              '((auipc a0 0) (addi a0 a0 8)))
(check-equal? (expand-la 'a0 5 #:mode 'abs)
              '((addi a0 x0 5)))
(check-equal? (expand-la 'a0 16 #:mode 'gp)
              '((addi a0 gp 16)))
(check-equal? (expand-la 'a0 16 #:mode 'frame #:base 'sp)
              '((addi a0 sp 16)))

(check-exn exn:fail?
           (lambda () (expand-la 'a0 16 #:mode 'frame)))
(check-exn exn:fail?
           (lambda () (expand-la 'a0 16 #:mode 'unknown)))

;; ------------------------------------------------------------
;; 自动 PC-relative 加载 load-pcrel / load-pcrel-size
;; ------------------------------------------------------------

;; 范围内：AUIPC + ADDI
(check-equal? (load-pcrel 'a0 8)
              '((auipc a0 0) (addi a0 a0 8)))
(check-equal? (load-pcrel-size 8) 8)

;; RV64 超范围：li + auipc + add
(define far-delta #x7fffffff)
(define far-li (li 't0 far-delta #:word-size 'rv64))
(check-equal? (load-pcrel 'a0 far-delta #:word-size 'rv64 #:scratch 't0)
              (append '((auipc a0 0))
                      far-li
                      '((add a0 a0 t0))))
(check-equal? (load-pcrel-size far-delta #:word-size 'rv64 #:scratch 't0)
              (+ (li-size far-delta #:word-size 'rv64) 8))

;; scratch 不能是 x0，也不能和 rd 相同。
(check-exn exn:fail?
           (lambda ()
             (load-pcrel 'a0 far-delta #:word-size 'rv64 #:scratch 'x0)))
(check-exn exn:fail?
           (lambda ()
             (load-pcrel 'a0 far-delta #:word-size 'rv64 #:scratch 'a0)))

;; 超范围且没有 scratch。
(check-exn exn:fail?
           (lambda () (load-pcrel 'a0 far-delta #:word-size 'rv64)))
(check-exn exn:fail?
           (lambda () (load-pcrel-size far-delta #:word-size 'rv64)))

;; RV32 没有 far 形式。
(check-exn exn:fail?
           (lambda () (load-pcrel 'a0 #x100000000 #:word-size 'rv32)))
(check-exn exn:fail?
           (lambda () (load-pcrel-size #x100000000 #:word-size 'rv32)))
