#lang racket/base

;; ============================================================
;; 跳转
;;
;; PC-relative:
;;   c.j / c.jal
;;   jal
;;   auipc + jalr
;;   far sequence
;;
;; 间接/绝对:
;;   jalr rd, base, imm12
;;   li/la tmp, target
;;   jalr rd, tmp, 0
;; ============================================================

(require "instruction.rkt"
         "ranges.rkt"
         "li.rkt"
         "scratch.rkt")

(define (check-even-offset who offset)
  (unless (even? offset)
    (error who "offset must be even, got ~a" offset)))

;; ------------------------------------------------------------
;; 叶子函数
;; ------------------------------------------------------------

(define (jump-cj offset)
  (unless (fits-cjump? offset)
    (error 'jump-cj "offset ~a does not fit C.J" offset))
  (list (I16 'c.j offset)))

(define (jump-cjal offset)
  (unless (fits-cjump? offset)
    (error 'jump-cjal "offset ~a does not fit C.JAL" offset))
  (list (I16 'c.jal offset)))

(define (jump-jal link offset)
  (unless (fits-jal? offset)
    (error 'jump-jal "offset ~a does not fit JAL" offset))
  (list (I 'jal link offset)))

(define (jump-auipc-jalr link offset
                         #:scratch [scratch #f]
                         #:word-size [word-size 'rv64])
  (check-even-offset 'jump-auipc-jalr offset)
  (unless (fits-pcrel-32? offset word-size)
    (error 'jump-auipc-jalr
           "offset ~a does not fit auipc+jalr"
           offset))

  (define regs (scratch-list scratch))
  (check-distinct! 'jump-auipc-jalr regs)
  (define-values (hi lo) (split-hi-lo offset))

  (cond
    [(eq? link 'zero)
     (define base (car (take-scratch! 'jump-auipc-jalr regs 1)))
     (check-not-zero! 'jump-auipc-jalr base)
     (list (I 'auipc base hi)
           (I 'jalr 'zero base lo))]
    [else
     (list (I 'auipc link hi)
           (I 'jalr link link lo))]))

(define (jump-jalr link base offset)
  (unless (fits-jalr12? offset)
    (error 'jump-jalr "offset ~a does not fit jalr imm12" offset))
  (list (I 'jalr link base offset)))

;; 超出 32 位 PC-relative 范围：
;;   先加载完整 offset
;;   auipc base, 0
;;   add   base, base, off-reg
;;   jalr  link, base, 0
(define (jump-far link offset
                  #:scratch [scratch #f]
                  #:word-size [word-size 'rv64])
  (check-even-offset 'jump-far offset)
  (when (eq? word-size 'rv32)
    (error 'jump-far "RV32 PC-relative offset out of range: ~a" offset))

  (define regs (scratch-list scratch))
  (check-distinct! 'jump-far regs)

  (cond
    [(eq? link 'zero)
     (define-values (base off-reg)
       (apply values (take-scratch! 'jump-far regs 2)))
     (check-not-zero! 'jump-far base)
     (check-not-zero! 'jump-far off-reg)
     (when (eq? base off-reg)
       (error 'jump-far "base and offset scratch must differ"))
     (append
      (expand-li off-reg offset #:word-size 'rv64)
      (list (I 'auipc base 0)
            (I 'add base base off-reg)
            (I 'jalr 'zero base 0)))]
    [else
     (define off-reg
       (car (take-scratch! 'jump-far regs 1)))
     (check-not-zero! 'jump-far off-reg)
     (when (eq? off-reg link)
       (error 'jump-far "offset scratch must differ from link register"))
     (append
      (expand-li off-reg offset #:word-size 'rv64)
      (list (I 'auipc link 0)
            (I 'add link link off-reg)
            (I 'jalr link link 0)))]))

;; 绝对/间接跳转：先把目标地址放进临时寄存器，再 jalr。
(define (jump-abs link target
                  #:scratch [scratch #f]
                  #:word-size [word-size 'rv64])
  (check-even-offset 'jump-abs target)
  (define temp (car (take-scratch! 'jump-abs (scratch-list scratch) 1)))
  (check-not-zero! 'jump-abs temp)
  (when (eq? temp link)
    (error 'jump-abs "temporary register must differ from link register"))
  (append
   (expand-li temp target #:word-size word-size)
   (list (I 'jalr link temp 0))))

;; ------------------------------------------------------------
;; 组合
;; ------------------------------------------------------------

(define (expand-jump offset
                     #:link [link 'zero]
                     #:scratch [scratch #f]
                     #:word-size [word-size 'rv64]
                     #:compressed? [compressed? #f])
  (check-even-offset 'expand-jump offset)

  (cond
    [(and compressed? (eq? link 'zero) (fits-cjump? offset))
     (jump-cj offset)]

    [(and compressed?
          (eq? link 'ra)
          (eq? word-size 'rv32)
          (fits-cjump? offset))
     (jump-cjal offset)]

    [(fits-jal? offset)
     (jump-jal link offset)]

    [(fits-pcrel-32? offset word-size)
     (jump-auipc-jalr link offset
                      #:scratch scratch
                      #:word-size word-size)]

    [else
     (jump-far link offset
               #:scratch scratch
               #:word-size word-size)]))

(provide jump-cj
         jump-cjal
         jump-jal
         jump-auipc-jalr
         jump-jalr
         jump-far
         jump-abs
         expand-jump)
