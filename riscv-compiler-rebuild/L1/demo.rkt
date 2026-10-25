#lang racket
;;; L1/demo.rkt -- 按表替换: 进 quote-list, 出 quote-list

(require "rewrite.rkt")

;; 程序整体是一个 quote-list
(define src
  '(begin
     (load-32  t0 sp 8)        ; 显式写法
     (ls8      t1 t0)          ; 简写, 省略 off
     (add      t1 t1 t0)       ; 真指令, 透传
     (store-64 sp 16 t1)       ; 地址在前, 值在后
     (ble      t1 t0 L)        ; 简写分支
     (move     t0 t1)          ; 显式 move
     (li       t2 42)          ; 真指令, 透传
     L))

;; 打印成 quote-list 的样子: '( ... )
(define (show x)
  (format "'~s" (if (quote-list? x) (cadr x) x)))

(displayln ";; P-asm")
(displayln (show src))

(define out (rewrite-program src))

(newline)
(displayln ";; after rewrite-program")
(displayln (show out))

(newline)
(displayln (format "quote-list? ~a" (quote-list? out)))
(displayln (format "pseudo leftover? ~a" (pseudo-leftover? out)))
