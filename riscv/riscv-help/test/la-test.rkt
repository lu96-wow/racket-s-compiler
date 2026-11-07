#lang racket/base

;; ============================================================
;; la：基础展开
;; ============================================================

(require rackunit
         "../la.rkt"
         "../li.rkt")

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
(check-equal? (load-pcrel-size 'a0 8) 8)

;; RV64 超范围：li + auipc + add
(define far-delta #x7fffffff)
(define far-li (li 't0 far-delta #:word-size 'rv64))
(check-equal? (load-pcrel 'a0 far-delta #:word-size 'rv64 #:scratch 't0)
              (append '((auipc a0 0))
                      far-li
                      '((add a0 a0 t0))))
(check-equal? (load-pcrel-size 'a0 far-delta #:word-size 'rv64 #:scratch 't0)
              (+ (li-size 't0 far-delta #:word-size 'rv64) 8))

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
           (lambda () (load-pcrel-size 'a0 far-delta #:word-size 'rv64)))

;; RV32 没有 far 形式。
(check-exn exn:fail?
           (lambda () (load-pcrel 'a0 #x100000000 #:word-size 'rv32)))
(check-exn exn:fail?
           (lambda () (load-pcrel-size 'a0 #x100000000 #:word-size 'rv32)))

;; ------------------------------------------------------------
;; size 与展开必须接受同一组输入
;;
;; load-pcrel-size 以前没有 rd, 所以 (scratch = rd) 这种展开时会被拒绝的输入,
;; 在 size 那边能算出长度 —— 失败被推迟到 encode。现在两边共用一个判据。
;; ------------------------------------------------------------

(check-exn exn:fail?
           (lambda ()
             (load-pcrel-size 'a0 far-delta #:word-size 'rv64 #:scratch 'a0)))
(check-exn exn:fail?
           (lambda ()
             (load-pcrel-size 'a0 far-delta #:word-size 'rv64 #:scratch 'x0)))
;; 只要不撞 rd 就照常算。
(check-equal? (load-pcrel-size 'a0 far-delta #:word-size 'rv64 #:scratch 'x1)
              (+ (li-size 'x1 far-delta #:word-size 'rv64) 8))

;; 一条 off-by-one 都不要: size 永远等于展开结果的字节数。
(for ([delta (in-list (list 8 4096 -8 far-delta #x100000000))]
      [scratch (in-list (list #f 't0))])
  (define size
    (with-handlers ([exn:fail? (lambda (_e) 'rejected)])
      (load-pcrel-size 'a0 delta #:word-size 'rv64 #:scratch scratch)))
  (define expansion
    (with-handlers ([exn:fail? (lambda (_e) 'rejected)])
      (load-pcrel 'a0 delta #:word-size 'rv64 #:scratch scratch)))
  (if (eq? size 'rejected)
      (check-eq? expansion 'rejected)
      (check-equal? size
                    (for/sum ([i (in-list expansion)])
                      (if (eq? (string-ref (symbol->string (car i)) 1) #\.) 2 4)))))

;; ------------------------------------------------------------
;; la-frame-size
;; ------------------------------------------------------------

(check-equal? (la-frame-size 'a0 'sp 16) 4)
(check-equal? (la-frame-size 'a0 'sp -2048) 4)
(check-equal? (la-frame-size 'a0 'sp 2048 #:scratch 't0) 12)
(check-equal? (la-frame-size 'a0 'sp 5000 #:scratch 't0) 12)
;; li 最坏 32 字节(general64) -> la-frame 最坏 36。
(check-equal? (la-frame-size 'a0 'sp #x123456789abcdef #:scratch 't0) 36)

;; 和展开一致。
(for ([offset (in-list (list 16 2047 2048 5000 #x123456789abcdef))])
  (check-equal? (la-frame-size 'a0 'sp offset #:scratch 't0)
                (* 4 (length (la-frame 'a0 'sp offset #:scratch 't0)))
                (format "la-frame-size(~a)" offset)))

;; 大 offset 没有 scratch / scratch 撞 rd、base, 两边都拒绝。
(for ([thunk (in-list
              (list (lambda () (la-frame 'a0 'sp 5000))
                    (lambda () (la-frame-size 'a0 'sp 5000))
                    (lambda () (la-frame 'a0 'sp 5000 #:scratch 'a0))
                    (lambda () (la-frame-size 'a0 'sp 5000 #:scratch 'a0))
                    (lambda () (la-frame 'a0 'sp 5000 #:scratch 'sp))
                    (lambda () (la-frame-size 'a0 'sp 5000 #:scratch 'sp))
                    (lambda () (la-frame-size 'a0 'sp 5000 #:scratch 'x0))))])
  (check-exn exn:fail? thunk))

;; 小 offset 不需要 scratch, 两边都不抱怨。
(check-equal? (la-frame-size 'a0 'sp 16) 4)
(check-equal? (la-frame 'a0 'sp 16) '((addi a0 sp 16)))
