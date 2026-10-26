#lang racket
;;; L2/demo.rkt -- 按表替换: 进 list, 出 list

(require "rewrite.rkt")

;; 程序就是一个 list
(define src
  '((load-32  t0 sp 8)        ; 显式写法
    (ls8      t1 t0)          ; 简写, 省略 off
    (add      t1 t1 t0)       ; 真指令, 透传
    (store-64 sp 16 t1)       ; 地址在前, 值在后
    (ble      t1 t0 L)        ; 简写分支
    (move     t0 t1)          ; 显式 move
    (li       t2 42)          ; 真指令, 透传
    L))

(define (show x) (format "~s" x))

(displayln ";; P-asm")
(displayln (show src))

(define out (rewrite-program src))

(newline)
(displayln ";; after rewrite-program")
(displayln (show out))

(newline)
(displayln (format "list? ~a" (list? out)))
(displayln (format "pseudo leftover? ~a" (pseudo-leftover? out)))
